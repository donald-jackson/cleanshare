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

        let manifestURL = self.inboxDir(root: root, token: token)
            .appendingPathComponent("manifest.json")
        guard let manifest = try? ManifestReader.read(from: manifestURL) else {
            return false
        }

        coordinator.pendingURLs = manifest.receipts.map(\.outputURL)
        self.scheduleCleanup(token: token, root: root)
        return true
    }

    /// Scans the App Group inbox for any pending manifests left behind by a
    /// share-extension run whose `openURL` handoff was dropped by iOS (a known
    /// iOS 17+ issue — the extension persists the manifest then asks iOS to
    /// switch apps, but iOS doesn't always honour the request even after the
    /// extension UI dismisses). Applies the most recent manifest to the
    /// coordinator and schedules cleanup of any older entries.
    ///
    /// Call from `CleanShareApp` on cold start and on transition to `.active`.
    /// Returns `true` if a pending manifest was applied.
    @MainActor
    @discardableResult
    static func applyPendingInbox(coordinator: ShareSheetCoordinator) -> Bool {
        guard let root = containerRoot() else { return false }
        let inboxRoot = root.appendingPathComponent("inbox", isDirectory: true)
        let fileManager = FileManager.default

        guard let entries = try? fileManager.contentsOfDirectory(
            at: inboxRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        // Sort newest first by mtime, then pick the first that contains a
        // readable manifest.json.
        let sorted = entries.sorted { lhs, rhs in
            let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? .distantPast
            return lDate > rDate
        }

        for tokenDir in sorted {
            let manifestURL = tokenDir.appendingPathComponent("manifest.json")
            guard let manifest = try? ManifestReader.read(from: manifestURL) else { continue }
            coordinator.pendingURLs = manifest.receipts.map(\.outputURL)
            self.scheduleCleanup(token: manifest.token, root: root)
            return true
        }
        return false
    }

    private static func containerRoot() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupID)
    }

    private static func inboxDir(root: URL, token: String) -> URL {
        root.appendingPathComponent("inbox", isDirectory: true)
            .appendingPathComponent(token, isDirectory: true)
    }

    private static func scheduleCleanup(token: String, root: URL) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(self.cleanupDelay * 1_000_000_000))
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: self.inboxDir(root: root, token: token))
            let jobDir = root.appendingPathComponent("tmp", isDirectory: true)
                .appendingPathComponent("job-\(token)", isDirectory: true)
            try? fileManager.removeItem(at: jobDir)
        }
    }
}
