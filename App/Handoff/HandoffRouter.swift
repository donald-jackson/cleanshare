import CleanShareCore
import Foundation

/// Host-app side of the extension → host handoff. Parses the `cleanshare://handoff`
/// token, loads the job manifest the extension wrote into the App Group inbox, and
/// posts the cleaned output URLs to the `ShareSheetCoordinator` so `RootView` can
/// present the system share sheet. See PLAN.md §6.
enum HandoffRouter {
    static let appGroupID = "group.dev.cleanshare.app"
    private static let cleanupDelay: TimeInterval = 60

    /// Returns `false` (silently) when the URL isn't a handoff, the App Group
    /// container is unavailable, or the manifest is missing/unreadable — never
    /// throws or crashes.
    @MainActor
    @discardableResult
    static func handle(_ url: URL, coordinator: ShareSheetCoordinator) -> Bool {
        guard let token = URL.handoffToken(from: url),
              let root = containerRoot() else { return false }

        let manifestURL = inboxDir(root: root, token: token)
            .appendingPathComponent("manifest.json")
        guard let manifest = try? ManifestReader.read(from: manifestURL) else {
            return false
        }

        coordinator.pendingURLs = manifest.receipts.map(\.outputURL)
        scheduleCleanup(token: token, root: root)
        return true
    }

    private static func containerRoot() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static func inboxDir(root: URL, token: String) -> URL {
        root.appendingPathComponent("inbox", isDirectory: true)
            .appendingPathComponent(token, isDirectory: true)
    }

    private static func scheduleCleanup(token: String, root: URL) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(cleanupDelay * 1_000_000_000))
            let fm = FileManager.default
            try? fm.removeItem(at: inboxDir(root: root, token: token))
            let jobDir = root.appendingPathComponent("tmp", isDirectory: true)
                .appendingPathComponent("job-\(token)", isDirectory: true)
            try? fm.removeItem(at: jobDir)
        }
    }
}
