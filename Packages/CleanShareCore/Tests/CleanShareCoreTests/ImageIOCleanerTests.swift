@testable import CleanShareCore
import XCTest

/// Golden-fixture coverage for `ImageIOCleaner`: each dirty fixture must clean
/// to leak-free output, verified both by the receipt and an independent
/// `MetadataAuditor` pass with an empty allowlist. See PLAN.md §8.2.
final class ImageIOCleanerTests: XCTestCase {
    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "missing fixture \(name).\(ext)"
        )
    }

    private func cleanAndAudit(_ name: String, _ ext: String, kind: MediaKind) async throws {
        let input = try fixtureURL(name, ext)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        defer { try? FileManager.default.removeItem(at: output) }

        let receipt = try await ImageIOCleaner().clean(
            input: input,
            output: output,
            prefs: CleaningPreferences()
        )

        XCTAssertEqual(receipt.kind, kind)
        XCTAssertTrue(receipt.leakedKeys.isEmpty, "receipt leaked: \(receipt.leakedKeys)")

        let leaks = try MetadataAuditor.audit(url: output, kind: kind, allowing: [])
        XCTAssertEqual(leaks, [], "auditor leaked: \(leaks)")
    }

    func testJPEGiPhoneSample() async throws {
        try await self.cleanAndAudit("iphone_sample", "jpg", kind: .jpeg)
    }

    func testJPEGPixelSample() async throws {
        try await self.cleanAndAudit("pixel_sample", "jpg", kind: .jpeg)
    }

    func testPNGTransparent() async throws {
        try await self.cleanAndAudit("transparent", "png", kind: .png)
    }

    func testGIFAnimated() async throws {
        try await self.cleanAndAudit("animated", "gif", kind: .gif)
    }

    func testJPEGLightroom() async throws {
        try await self.cleanAndAudit("lightroom", "jpg", kind: .jpeg)
    }
}
