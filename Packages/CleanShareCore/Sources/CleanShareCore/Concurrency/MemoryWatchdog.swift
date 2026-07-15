import Foundation

/// A footprint threshold crossing observed by the ``MemoryWatchdog``.
public enum MemoryEvent: Sendable, Equatable {
    case warning(megabytes: Int)
    case critical(megabytes: Int)
}

/// Polls the process's resident memory footprint and emits threshold-crossing
/// events so a cleaning job can abort before the ~120 MB share-extension jetsam
/// limit kills the whole extension. See PLAN.md §5.1.
public actor MemoryWatchdog {
    private let pollInterval: Duration
    private var pollingTask: Task<Void, Never>?
    private var warned = false
    private var criticalEmitted = false

    public init(pollInterval: Duration = .milliseconds(250)) {
        self.pollInterval = pollInterval
    }

    /// Current resident memory footprint of this process, in whole megabytes.
    public func footprintMB() async -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        // `task_self_trap()` returns the current task's send right — the same port
        // as the `mach_task_self_` global — but as a function call it sidesteps
        // Swift 6.0's "reference to var is not concurrency-safe" error on that
        // global var (newer SDKs annotate it; the older CI toolchain does not).
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task_self_trap(), task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.resident_size / (1024 * 1024))
    }

    /// Starts polling the footprint, yielding `.warning` once it first exceeds
    /// 80 MB and `.critical` once it first exceeds 90 MB. The same event is not
    /// re-emitted on subsequent polls.
    public func start() -> AsyncStream<MemoryEvent> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    let megabytes = await footprintMB()
                    if megabytes > 90, !self.criticalEmitted {
                        self.criticalEmitted = true
                        continuation.yield(.critical(megabytes: megabytes))
                    } else if megabytes > 80, !self.warned {
                        self.warned = true
                        continuation.yield(.warning(megabytes: megabytes))
                    }
                    try? await Task.sleep(for: self.pollInterval)
                }
                continuation.finish()
            }
            self.pollingTask = task
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Cancels the polling task started by ``start()``.
    public func stop() {
        self.pollingTask?.cancel()
        self.pollingTask = nil
    }
}
