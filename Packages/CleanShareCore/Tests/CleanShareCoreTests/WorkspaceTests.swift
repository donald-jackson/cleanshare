import XCTest
@testable import CleanShareCore

/// Coverage for the `Workspace` actor: job directory creation, targeted cleanup,
/// and TTL-based expiry. Runs against the `NSTemporaryDirectory()` fallback since
/// the App Group entitlement is absent in unit tests. See PLAN.md §5.3.
final class WorkspaceTests: XCTestCase {
    func testJobLifecycleAndExpiry() async throws {
        let fm = FileManager.default
        let workspace = try Workspace(appGroupID: "group.dev.cleanshare.app.tests")

        let jobA = try await workspace.newJob()
        let jobB = try await workspace.newJob()

        XCTAssertTrue(fm.fileExists(atPath: jobA.inDir.path))
        XCTAssertTrue(fm.fileExists(atPath: jobA.outDir.path))
        XCTAssertTrue(fm.fileExists(atPath: jobB.inDir.path))
        XCTAssertTrue(fm.fileExists(atPath: jobB.outDir.path))

        try await workspace.cleanup(jobID: jobA.id)
        XCTAssertFalse(fm.fileExists(atPath: jobA.inDir.path))
        XCTAssertTrue(fm.fileExists(atPath: jobB.inDir.path))

        try await workspace.cleanupExpired(olderThan: 0)
        XCTAssertFalse(fm.fileExists(atPath: jobB.inDir.path))
    }
}
