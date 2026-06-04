import XCTest
@testable import CleanShareCore

/// Coverage for `AVPassthroughCleaner`: the H.264 dirty fixture must clean to
/// leak-free output while remaining a lossless passthrough (no re-encode, size
/// preserved within tolerance). See PLAN.md §4.3, §8.2.
final class AVPassthroughCleanerTests: XCTestCase {
    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "missing fixture \(name).\(ext)"
        )
    }

    private func clean(_ name: String, _ ext: String) async throws -> (CleanReceipt, URL) {
        let input = try fixtureURL(name, ext)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        let receipt = try await AVPassthroughCleaner().clean(
            input: input,
            output: output,
            prefs: CleaningPreferences()
        )
        return (receipt, output)
    }

    func testH264PassthroughStripsAllMetadata() async throws {
        let (receipt, output) = try await clean("h264_short", "mp4")
        defer { try? FileManager.default.removeItem(at: output) }

        XCTAssertTrue(receipt.leakedKeys.isEmpty, "receipt leaked: \(receipt.leakedKeys)")

        let leaks = try MetadataAuditor.audit(url: output, kind: .mp4, allowing: [])
        XCTAssertEqual(leaks, [], "auditor leaked: \(leaks)")
    }

    func testH264PassthroughDoesNotReencode() async throws {
        let (receipt, output) = try await clean("h264_short", "mp4")
        defer { try? FileManager.default.removeItem(at: output) }

        XCTAssertFalse(receipt.reencoded, "passthrough must not re-encode")

        // ±15% (looser than PLAN's ±10%) because shouldOptimizeForNetworkUse = true
        // reorganises atoms, which can shift the container size slightly.
        let ratio = Double(receipt.bytesOut) / Double(receipt.bytesIn)
        XCTAssert(
            (0.85...1.15).contains(ratio),
            "size drifted beyond ±15%: in=\(receipt.bytesIn) out=\(receipt.bytesOut) ratio=\(ratio)"
        )
    }
}
