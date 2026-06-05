import CleanShareCore
import CleanShareUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Entry point for the share extension. Cleans every attached photo/video in the
/// App Group workspace, writes a handoff manifest, then opens the host app to
/// re-present the system share sheet. See PLAN.md §3.1 and §6.
final class ShareViewController: UIViewController {
    private let appGroupID = "group.dev.cleanshare.app"
    private let progressModel = CleaningProgressModel()
    private var pipeline: CleaningPipeline?
    private var workTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        self.installProgressView()
        self.workTask = Task { [weak self] in await self?.runCleaning() }
    }

    private func installProgressView() {
        let host = UIHostingController(
            rootView: CleaningProgressView(progress: progressModel) { [weak self] in
                self?.cancel()
            }
        )
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            host.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            host.view.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            host.view.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
        host.didMove(toParent: self)
    }

    private func runCleaning() async {
        do {
            let workspace = try Workspace(appGroupID: appGroupID)
            let job = try await workspace.newJob()

            var items: [CleaningPipeline.InputItem] = []
            var names: [UUID: String] = [:]
            for provider in self.attachments() {
                guard let (url, kind) = try await loadFile(from: provider, into: job.inDir) else { continue }
                let id = UUID()
                items.append((id: id, sourceURL: url, kind: kind))
                names[id] = url.lastPathComponent
            }

            guard !items.isEmpty else {
                extensionContext?.completeRequest(returningItems: nil)
                return
            }

            let pipeline = CleaningPipeline(workspace: workspace, prefs: CleaningPreferences())
            self.pipeline = pipeline
            await pipeline.enqueue(items)

            var receipts: [CleanReceipt] = []
            let total = Double(items.count)
            let events = await pipeline.run()
            for try await event in events {
                switch event {
                case .progress(let itemID, _):
                    self.progressModel.currentFile = names[itemID]
                case .completed(_, let receipt):
                    receipts.append(receipt)
                    self.progressModel.fraction = Double(receipts.count) / total
                case .failed:
                    break
                }
            }

            try Task.checkCancellation()

            let token = job.id.uuidString
            let manifest = Manifest(token: token, receipts: receipts)
            let manifestURL = try await workspace.inboxManifestURL(token: token)
            try ManifestWriter.write(manifest, to: manifestURL)

            self.handOff(token: token, cleanedURLs: receipts.map(\.outputURL))
        } catch is CancellationError {
            // Cancellation already finished the request via cancel().
        } catch {
            extensionContext?.cancelRequest(withError: error)
        }
    }

    private func handOff(token: String, cleanedURLs: [URL]) {
        let arbiter = HandOffArbiter()

        // Some iOS releases never invoke `open(_:completionHandler:)` from a share
        // extension when it was launched from another app's share sheet (e.g.
        // WhatsApp). Guard the ladder with a hard timeout so the user never hangs
        // on the progress view; fall back to Files if no callback in 4s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, arbiter.claim() else { return }
            NSLog("CleanShare: NSExtensionContext.open() never called back; using Files fallback")
            self.presentFilesFallback(cleanedURLs)
        }

        // Apple's blessed path is the Universal Link (https). Try it first; if the
        // associated domain isn't resolvable yet, retry the custom scheme; if both
        // report failure, fall to Files. See PLAN.md §6.3.
        let ladder = [URL.handoff(token: token), URL.handoffCustomScheme(token: token)]
        self.openHandoff(ladder, from: 0, arbiter: arbiter, cleanedURLs: cleanedURLs)
    }

    /// Walks the handoff URL ladder: opens `urls[index]`, and on `opened == false`
    /// recurses to the next URL. The first success claims the arbiter and finishes
    /// the request; exhausting the ladder claims the arbiter and presents Files.
    @MainActor
    private func openHandoff(
        _ urls: [URL],
        from index: Int,
        arbiter: HandOffArbiter,
        cleanedURLs: [URL]
    ) {
        guard index < urls.count else {
            guard arbiter.claim() else { return }
            NSLog("CleanShare: all handoff URLs returned false; using Files fallback")
            self.presentFilesFallback(cleanedURLs)
            return
        }

        let url = urls[index]
        extensionContext?.open(url) { [weak self] opened in
            Task { @MainActor in
                guard let self else { return }
                if opened {
                    guard arbiter.claim() else { return }
                    self.extensionContext?.completeRequest(returningItems: nil)
                } else {
                    NSLog("CleanShare: handoff open(%@) returned false; trying next", url.absoluteString)
                    self.openHandoff(urls, from: index + 1, arbiter: arbiter, cleanedURLs: cleanedURLs)
                }
            }
        }
    }

    private func presentFilesFallback(_ urls: [URL]) {
        guard !urls.isEmpty else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        let picker = UIDocumentPickerViewController(forExporting: urls)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func cancel() {
        Task { @MainActor in
            await self.pipeline?.cancel()
            self.workTask?.cancel()
            self.extensionContext?.cancelRequest(
                withError: NSError(domain: "dev.cleanshare.share", code: NSUserCancelledError)
            )
        }
    }

    // MARK: - Attachments

    private func attachments() -> [NSItemProvider] {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        return items.flatMap { $0.attachments ?? [] }
    }

    /// Loads one attachment's file representation and hardlinks (or copies, across
    /// volumes) it into `inDir`. The provided URL is only valid inside the
    /// completion handler, so the link/copy happens there. Returns `nil` for
    /// attachments that don't resolve to a supported `MediaKind`.
    private func loadFile(
        from provider: NSItemProvider,
        into inDir: URL
    ) async throws -> (URL, MediaKind)? {
        guard let typeID = provider.registeredTypeIdentifiers.first(where: { id in
            guard let type = UTType(id) else { return false }
            return type.conforms(to: .image) || type.conforms(to: .movie)
        }) else { return nil }

        let dest: URL = try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(
                        throwing: NSError(domain: "dev.cleanshare.share", code: -1)
                    )
                    return
                }
                let dest = inDir.appendingPathComponent(url.lastPathComponent)
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: dest)
                do {
                    do {
                        try fileManager.linkItem(at: url, to: dest)
                    } catch {
                        try fileManager.copyItem(at: url, to: dest)
                    }
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        guard let kind = mediaKind(for: dest, fallbackTypeID: typeID) else { return nil }
        return (dest, kind)
    }

    private func mediaKind(for url: URL, fallbackTypeID: String) -> MediaKind? {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           let kind = MediaKind(uti: contentType) {
            return kind
        }
        if let type = UTType(fallbackTypeID), let kind = MediaKind(uti: type) {
            return kind
        }
        if let type = UTType(filenameExtension: url.pathExtension), let kind = MediaKind(uti: type) {
            return kind
        }
        return nil
    }
}

extension ShareViewController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
        extensionContext?.completeRequest(returningItems: nil)
    }

    func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// Single-fire arbiter ensuring that exactly one of (open-completion, timeout)
/// drives the post-handoff action. Without this, the timeout closure and the
/// open() completion can race and present the Files picker twice (or call
/// completeRequest after presenting it).
///
/// `@unchecked Sendable` is sound here: the only mutable state is `claimed`,
/// and every access is serialized by `lock`. See PLAN.md §7.2.
private final class HandOffArbiter: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// Returns `true` exactly once across all callers; subsequent calls return `false`.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}
