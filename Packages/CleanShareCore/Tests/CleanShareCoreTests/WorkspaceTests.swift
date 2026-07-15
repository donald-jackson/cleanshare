@testable import CleanShareCore
import XCTest

/// Coverage for the `Workspace` actor: job directory creation, targeted cleanup,
/// and TTL-based expiry. Runs against the `NSTemporaryDirectory()` fallback since
/// the App Group entitlement is absent in unit tests. See PLAN.md §5.3.
final class WorkspaceTests: XCTestCase {
    func testJobLifecycleAndExpiry() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("CleanShareTests-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: root) }
        let workspace = Workspace(rootDirectory: root)

        let jobA = try await workspace.newJob()
        let jobB = try await workspace.newJob()

        XCTAssertTrue(fileManager.fileExists(atPath: jobA.inDir.path))
        XCTAssertTrue(fileManager.fileExists(atPath: jobA.outDir.path))
        XCTAssertTrue(fileManager.fileExists(atPath: jobB.inDir.path))
        XCTAssertTrue(fileManager.fileExists(atPath: jobB.outDir.path))

        try await workspace.cleanup(jobID: jobA.id)
        XCTAssertFalse(fileManager.fileExists(atPath: jobA.inDir.path))
        XCTAssertTrue(fileManager.fileExists(atPath: jobB.inDir.path))

        try await workspace.cleanupExpired(olderThan: 0)
        XCTAssertFalse(fileManager.fileExists(atPath: jobB.inDir.path))
    }
}
