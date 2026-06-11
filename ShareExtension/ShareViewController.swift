import CleanShareCore
import CleanShareUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

/// Entry point for the share extension. Cleans every attached photo/video in
/// the App Group workspace, writes a handoff manifest, schedules a local
/// notification the user taps to continue sharing in the host app, then
/// dismisses itself. See PLAN.md §3.1 and §6.
final class ShareViewController: UIViewController {
    private let appGroupID = "group.solutions.ddj.cleanshare"
    /// Time the success state is shown before the extension dismisses
    /// itself. Long enough to read "Cleaned", short enough not to feel like a
    /// stall.
    private let successDisplayDuration: TimeInterval = 0.8
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
            rootView: CleaningProgressView(
                progress: progressModel,
                onCancel: { [weak self] in self?.cancel() }
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

            // Flash the success state ("Cleaned") for a beat so the user sees
            // confirmation, then post the local notification and dismiss the
            // extension. The notification is the user-driven hook back into
            // the host app; the inbox sweep covers the case where the user
            // denied notification permission.
            self.progressModel.fraction = 1.0
            self.progressModel.phase = .ready

            await self.postReadyNotification(token: token, itemCount: receipts.count)
            try? await Task.sleep(nanoseconds: UInt64(self.successDisplayDuration * 1_000_000_000))
            self.extensionContext?.completeRequest(returningItems: nil)
        } catch is CancellationError {
            // Cancellation already finished the request via cancel().
        } catch {
            extensionContext?.cancelRequest(withError: error)
        }
    }

    /// Posts a local notification the user taps to continue sharing in the
    /// host app. The token is carried in `userInfo` so the host's notification
    /// delegate can route the tap directly to the right manifest. Requests
    /// authorization first (idempotent if the user has already answered).
    private func postReadyNotification(token: String, itemCount: Int) async {
        let center = UNUserNotificationCenter.current()
        // Idempotent: if the user already answered, the existing setting wins
        // and no prompt is shown. If they denied, .add(_:) will silently fail
        // — that's fine, the host-app inbox sweep is the backup.
        _ = try? await center.requestAuthorization(options: [.alert, .sound])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Cleaned & ready to share")
        content.body = itemCount > 1
            ? String(localized: "Tap to share \(itemCount) cleaned files via CleanShare.")
            : String(localized: "Tap to share your cleaned file via CleanShare.")
        content.sound = .default
        content.categoryIdentifier = URL.handoffNotificationCategory
        content.userInfo = [URL.handoffNotificationTokenKey: token]
        // Token doubles as the request id — re-posting for the same job would
        // be a bug, but this guarantees no duplicates either way.
        let request = UNNotificationRequest(identifier: token, content: content, trigger: nil)
        try? await center.add(request)
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

