@testable import CleanShareCore
import XCTest

/// Verifies that `CleaningPipeline` routes a batch of image items through the
/// correct cleaner and emits exactly one `.completed` event per item, with no
/// failures. See PLAN.md §4.6 and §7.3.
final class CleaningPipelineTests: XCTestCase {
    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "missing fixture \(name).\(ext)"
        )
    }

    func testProcessesThreeImagesAndYieldsThreeCompletedEvents() async throws {
        let workspace = try Workspace(appGroupID: "group.dev.cleanshare.app")
        let pipeline = CleaningPipeline(workspace: workspace, prefs: CleaningPreferences())

        let items: [CleaningPipeline.InputItem] = try [
            (id: UUID(), sourceURL: self.fixtureURL("iphone_sample", "jpg"), kind: .jpeg),
            (id: UUID(), sourceURL: self.fixtureURL("pixel_sample", "jpg"), kind: .jpeg),
            (id: UUID(), sourceURL: self.fixtureURL("transparent", "png"), kind: .png)
        ]
        await pipeline.enqueue(items)

        var completed = 0
        var failed = 0
        let stream = await pipeline.run()
        for try await event in stream {
            switch event {
            case .completed: completed += 1
            case .failed: failed += 1
            case .progress: break
            }
        }

        XCTAssertEqual(completed, 3, "expected three cleaned images")
        XCTAssertEqual(failed, 0, "expected no failures")
    }
}
