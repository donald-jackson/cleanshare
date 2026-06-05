import CleanShareCore
import CleanShareUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Entry point for the share extension. Cleans every attached photo/video in the
/// App Group workspace, writes a handoff manifest, then opens the host app to
/// re-present the system share sheet. See PLAN.md §3.1 and §6.
final class ShareViewController: UIViewController {
    private let appGroupID = "group.solutions.ddj.cleanshare"
    private let progressModel = CleaningProgressModel()
    private var pipeline: CleaningPipeline?
    private var workTask: Task<Void, Never>?
    /// Job token captured at the end of `runCleaning`. Drives the "Open
    /// CleanShare" button — when the user taps it we hand this token to the
    /// host app via the `cleanshare://handoff` URL.
    private var pendingToken: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        self.installProgressView()
        self.workTask = Task { [weak self] in await self?.runCleaning() }
    }

    private func installProgressView() {
        let host = UIHostingController(
            rootView: CleaningProgressView(
                progress: progressModel,
                onCancel: { [weak self] in self?.cancel() },
                onContinue: { [weak self] in self?.openHostApp() }
            )
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

            // Flip the progress view into its success state — checkmark + the
            // "Cleaned & ready. Open CleanShare to continue." prompt + an
            // explicit "Open CleanShare" CTA. We deliberately do NOT auto-launch
            // the host app: iOS 17+ has made that flow unreliable from share
            // extensions invoked through another app's share sheet, so we
            // surface the next step honestly and let the user trigger it with
            // a fresh user gesture (which gives `openURL:` its best shot).
            self.progressModel.fraction = 1.0
            self.progressModel.phase = .ready
            self.pendingToken = token
        } catch is CancellationError {
            // Cancellation already finished the request via cancel().
        } catch {
            extensionContext?.cancelRequest(withError: error)
        }
    }

    /// Invoked when the user taps "Open CleanShare" in the success state of
    /// the share-extension UI. Dismisses the extension first (iOS 17+ refuses
    /// app switches while an extension is foregrounded), then walks the
    /// responder chain inside the dismissal's completion handler to fire
    /// `openURL:` against whatever responds (effectively UIApplication).
    ///
    /// If iOS still drops the open (some 17.x builds do, even with a fresh
    /// user gesture), the user's only friction is one extra tap: the manifest
    /// is already in the App Group inbox and `HandoffRouter.applyPendingInbox`
    /// auto-presents the share sheet the next time CleanShare comes to the
    /// foreground — provided the manifest is fresher than 3 minutes.
    private func openHostApp() {
        guard let token = self.pendingToken else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        let url = URL.handoffCustomScheme(token: token)
        extensionContext?.completeRequest(returningItems: nil) { [weak self] _ in
            // Hop to the main actor — UIResponder.next is MainActor-isolated and
            // the completion handler arrives on an arbitrary queue.
            Task { @MainActor [weak self] in
                guard let self else { return }
                var responder: UIResponder? = self
                let selector = NSSelectorFromString("openURL:")
                while let current = responder {
                    if current.responds(to: selector) {
                        _ = current.perform(selector, with: url)
                        return
                    }
                    responder = current.next
                }
                NSLog("CleanShare: responder chain exhausted; manifest will be picked up on next CleanShare foreground")
            }
        }
    }

    private func cancel() {
        Task { @MainActor in
            await self.pipeline?.cancel()
            self.workTask?.cancel()
            self.extensionContext?.cancelRequest(
                withError: NSError(domain: "solutions.ddj.cleanshare.share", code: NSUserCancelledError)
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
                        throwing: NSError(domain: "solutions.ddj.cleanshare.share", code: -1)
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

