import Foundation

/// Orchestrates a batch of single-file cleaners under a bounded concurrency
/// budget. Each enqueued item is routed to the cleaner that matches its
/// `MediaKind`, run inside a `withDiscardingTaskGroup` gated to `maxConcurrent`
/// in-flight jobs, and surfaced as a stream of `CleanEvent`s. The slot gate keeps
/// peak memory inside the share-extension cap. See PLAN.md §4.6 and §7.3.
public actor CleaningPipeline {
    /// A unit of work: a stable id, the source media URL, and its detected kind.
    public typealias InputItem = (id: UUID, sourceURL: URL, kind: MediaKind)

    private let workspace: Workspace
    private let prefs: CleaningPreferences
    private let maxConcurrent: Int

    private var queue: [InputItem] = []
    private var isCancelled = false
    private var processingTask: Task<Void, Never>?

    // Counting slot gate backing the bounded task group (PLAN.md §7.3).
    private var availableSlots: Int
    private var slotWaiters: [CheckedContinuation<Void, Never>] = []

    public init(workspace: Workspace, prefs: CleaningPreferences, maxConcurrent: Int = 2) {
        self.workspace = workspace
        self.prefs = prefs
        self.maxConcurrent = max(1, maxConcurrent)
        self.availableSlots = max(1, maxConcurrent)
    }

    /// Appends items to the pending queue. Call before `run()`.
    public func enqueue(_ items: [InputItem]) {
        queue.append(contentsOf: items)
    }

    /// Requests cancellation: stops scheduling new items and cancels the
    /// in-flight processing task so ongoing cleaners hit `Task.checkCancellation()`.
    public func cancel() async {
        isCancelled = true
        processingTask?.cancel()
    }

    /// Drains the queue, emitting a `CleanEvent` per state transition. The stream
    /// finishes when every item has produced a terminal event, or with an error if
    /// the workspace job directory cannot be created.
    public func run() -> AsyncThrowingStream<CleanEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream<CleanEvent, Error>.makeStream()
        let task = Task { await self.process(yielding: continuation) }
        continuation.onTermination = { _ in task.cancel() }
        processingTask = task
        return stream
    }

    private func process(yielding continuation: AsyncThrowingStream<CleanEvent, Error>.Continuation) async {
        do {
            let job = try await workspace.newJob()
            let items = queue
            // iOS 17 (the shipping target) always takes the discarding path, which
            // reaps finished children eagerly. The plain-group fallback only exists
            // for the macOS 13 host-test build, where DiscardingTaskGroup is absent.
            if #available(iOS 17.0, macOS 14.0, *) {
                await withDiscardingTaskGroup { group in
                    for item in items {
                        if isCancelled || Task.isCancelled { break }
                        await acquireSlot()
                        group.addTask {
                            await self.processItem(item, outDir: job.outDir, yielding: continuation)
                            await self.releaseSlot()
                        }
                    }
                }
            } else {
                await withTaskGroup(of: Void.self) { group in
                    for item in items {
                        if isCancelled || Task.isCancelled { break }
                        await acquireSlot()
                        group.addTask {
                            await self.processItem(item, outDir: job.outDir, yielding: continuation)
                            await self.releaseSlot()
                        }
                    }
                }
            }
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    private func processItem(
        _ item: InputItem,
        outDir: URL,
        yielding continuation: AsyncThrowingStream<CleanEvent, Error>.Continuation
    ) async {
        do {
            try Task.checkCancellation()
            let cleaner = try makeCleaner(for: item.kind)
            let output = outDir.appendingPathComponent("\(item.id.uuidString)-\(item.sourceURL.lastPathComponent)")

            continuation.yield(.progress(itemID: item.id, fraction: 0))
            let receipt = try await cleaner.clean(input: item.sourceURL, output: output, prefs: prefs)
            continuation.yield(.progress(itemID: item.id, fraction: 1))
            continuation.yield(.completed(itemID: item.id, receipt: receipt))
        } catch let error as CleanerError {
            continuation.yield(.failed(itemID: item.id, error: error))
        } catch is CancellationError {
            continuation.yield(.failed(itemID: item.id, error: .cancelled))
        } catch {
            continuation.yield(.failed(itemID: item.id, error: .avFailed(reason: error.localizedDescription)))
        }
    }

    private func makeCleaner(for kind: MediaKind) throws -> any Cleaner {
        switch kind {
        case .jpeg, .heic, .heif, .png, .gif, .webp, .tiff, .dng:
            return ImageIOCleaner()
        case .mp4, .mov:
            return AVPassthroughCleaner()
        case .livePhoto:
            throw CleanerError.unsupportedFormat("Live Photo cleaning is not yet supported by CleaningPipeline")
        }
    }

    // MARK: - Slot gate

    private func acquireSlot() async {
        if availableSlots > 0 {
            availableSlots -= 1
            return
        }
        await withCheckedContinuation { slotWaiters.append($0) }
    }

    private func releaseSlot() {
        if slotWaiters.isEmpty {
            availableSlots += 1
        } else {
            slotWaiters.removeFirst().resume()
        }
    }
}

/// A single state transition while cleaning one batch item.
public enum CleanEvent: Sendable {
    case progress(itemID: UUID, fraction: Double)
    case completed(itemID: UUID, receipt: CleanReceipt)
    case failed(itemID: UUID, error: CleanerError)
}
