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
    private let fm = FileManager.default

    /// Resolves the App Group container via
    /// `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. When
    /// that returns `nil` — e.g. in unit tests, where the App Group entitlement
    /// is absent — falls back to `NSTemporaryDirectory()/CleanShareWorkspace/`.
    public init(appGroupID: String) throws {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            root = container
        } else {
            root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("CleanShareWorkspace", isDirectory: true)
        }
    }

    private var tmpDir: URL { root.appendingPathComponent("tmp", isDirectory: true) }
    private var inboxDir: URL { root.appendingPathComponent("inbox", isDirectory: true) }

    /// Creates a fresh `tmp/job-<uuid>/` directory tree (with `in/` and `out/`
    /// subdirectories) and returns the resolved URLs.
    public func newJob() throws -> JobURLs {
        let id = UUID()
        let jobDir = tmpDir.appendingPathComponent("job-\(id.uuidString)", isDirectory: true)
        let inDir = jobDir.appendingPathComponent("in", isDirectory: true)
        let outDir = jobDir.appendingPathComponent("out", isDirectory: true)

        try fm.createDirectory(at: inDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

        return JobURLs(
            id: id,
            inDir: inDir,
            outDir: outDir,
            manifestURL: jobDir.appendingPathComponent("manifest.json")
        )
    }

    /// Removes `tmp/job-<id>` recursively. No-op if it does not exist.
    public func cleanup(jobID: UUID) throws {
        let jobDir = tmpDir.appendingPathComponent("job-\(jobID.uuidString)", isDirectory: true)
        if fm.fileExists(atPath: jobDir.path) {
            try fm.removeItem(at: jobDir)
        }
    }

    /// Walks `tmp/job-*` and `inbox/*`, removing any entry whose creation date is
    /// older than `Date().addingTimeInterval(-ttl)`.
    public func cleanupExpired(olderThan ttl: TimeInterval) throws {
        let cutoff = Date().addingTimeInterval(-ttl)
        for dir in [tmpDir, inboxDir] {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.creationDateKey],
                options: []
            ) else { continue }
            for entry in entries {
                let created = try entry.resourceValues(forKeys: [.creationDateKey]).creationDate
                if let created, created < cutoff {
                    try fm.removeItem(at: entry)
                }
            }
        }
    }
}
