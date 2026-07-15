import Foundation

/// File-system locations for a single cleaning job, rooted under the workspace's
/// `tmp/job-<id>/` directory. See PLAN.md §5.3.
public struct JobURLs: Sendable {
    public let id: UUID
    public let inDir: URL
    public let outDir: URL
    public let manifestURL: URL
}

/// Serializes all file-system operations for the App Group workspace that backs
/// the extension → host handoff. The on-disk layout (`tmp/job-<uuid>/`,
/// `inbox/<token>/`) is described in PLAN.md §5.3; the workspace lives in the App
/// Group container so it survives the extension → host handoff (PLAN.md §3.1).
public actor Workspace {
    private let root: URL
    private let fileManager = FileManager.default

    /// Resolves the App Group container via
    /// `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. When
    /// that returns `nil` — e.g. in unit tests, where the App Group entitlement
    /// is absent — falls back to `NSTemporaryDirectory()/CleanShareWorkspace/`.
    public init(appGroupID: String) throws {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            self.root = container
        } else {
            self.root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("CleanShareWorkspace", isDirectory: true)
        }
    }

    /// Roots the workspace at an explicit directory. Used by unit tests, where
    /// the App Group container is either absent or (on a machine that also ran a
    /// signed build) present but not writable by the unsigned test process.
    init(rootDirectory: URL) {
        self.root = rootDirectory
    }

    private var tmpDir: URL {
        self.root.appendingPathComponent("tmp", isDirectory: true)
    }

    private var inboxDir: URL {
        self.root.appendingPathComponent("inbox", isDirectory: true)
    }

    /// Creates a fresh `tmp/job-<uuid>/` directory tree (with `in/` and `out/`
    /// subdirectories) and returns the resolved URLs.
    public func newJob() throws -> JobURLs {
        let id = UUID()
        let jobDir = self.tmpDir.appendingPathComponent("job-\(id.uuidString)", isDirectory: true)
        let inDir = jobDir.appendingPathComponent("in", isDirectory: true)
        let outDir = jobDir.appendingPathComponent("out", isDirectory: true)

        try self.fileManager.createDirectory(at: inDir, withIntermediateDirectories: true)
        try self.fileManager.createDirectory(at: outDir, withIntermediateDirectories: true)

        return JobURLs(
            id: id,
            inDir: inDir,
            outDir: outDir,
            manifestURL: jobDir.appendingPathComponent("manifest.json")
        )
    }

    /// Creates `inbox/<token>/` (if needed) and returns the URL where that job's
    /// `manifest.json` should be written for the host app to pick up. See PLAN.md §6.
    public func inboxManifestURL(token: String) throws -> URL {
        let dir = self.inboxDir.appendingPathComponent(token, isDirectory: true)
        try self.fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("manifest.json")
    }

    /// Removes `tmp/job-<id>` recursively. No-op if it does not exist.
    public func cleanup(jobID: UUID) throws {
        let jobDir = self.tmpDir.appendingPathComponent("job-\(jobID.uuidString)", isDirectory: true)
        if self.fileManager.fileExists(atPath: jobDir.path) {
            try self.fileManager.removeItem(at: jobDir)
        }
    }

    /// Walks `tmp/job-*` and `inbox/*`, removing any entry whose creation date is
    /// older than `Date().addingTimeInterval(-ttl)`.
    public func cleanupExpired(olderThan ttl: TimeInterval) throws {
        let cutoff = Date().addingTimeInterval(-ttl)
        for dir in [self.tmpDir, self.inboxDir] {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.creationDateKey],
                options: []
            ) else { continue }
            for entry in entries {
                let created = try entry.resourceValues(forKeys: [.creationDateKey]).creationDate
                if let created, created < cutoff {
                    try self.fileManager.removeItem(at: entry)
                }
            }
        }
    }
}
