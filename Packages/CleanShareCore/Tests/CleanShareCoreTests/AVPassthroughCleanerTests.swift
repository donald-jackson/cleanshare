import AVFoundation
@testable import CleanShareCore
import XCTest

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

        // Video MUST be audited with the async video verifier — the synchronous
        // `audit(kind:.mp4)` returns [] unconditionally and proves nothing.
        let leaks = try await MetadataAuditor.auditVideo(url: output, allowing: [])
        XCTAssertEqual(leaks, [], "auditor leaked: \(leaks)")
    }

    /// Guards the verifier itself: the dirty fixture carries an encoder tag and a
    /// 3GPP `loci` GPS box, so auditing it WITHOUT cleaning must report a leak.
    /// If this returns empty, the video verifier has a coverage gap and every
    /// "clean" claim built on it is hollow.
    func testAuditVideoDetectsMetadataInUncleanedFixture() async throws {
        let dirty = try fixtureURL("h264_short", "mp4")
        let leaks = try await MetadataAuditor.auditVideo(url: dirty, allowing: [])
        XCTAssertFalse(leaks.isEmpty, "verifier failed to detect metadata in the dirty fixture")
    }

    /// The raw box-tree scan must see the `loci` GPS box that AVFoundation's
    /// metadata API hides — the exact blind spot that let GPS pass unverified.
    func testLocationBoxScanDetectsGPSInDirtyFixtureButNotCleanedOutput() async throws {
        let dirty = try fixtureURL("h264_short", "mp4")
        XCTAssertTrue(
            MetadataAuditor.locationBoxes(in: dirty).contains("loci"),
            "raw scan missed the dirty fixture's loci GPS box"
        )

        let (_, output) = try await clean("h264_short", "mp4")
        defer { try? FileManager.default.removeItem(at: output) }
        XCTAssertEqual(
            MetadataAuditor.locationBoxes(in: output), [],
            "cleaned output still carries a location box"
        )
    }

    func testH264PassthroughDoesNotReencode() async throws {
        let (receipt, output) = try await clean("h264_short", "mp4")
        defer { try? FileManager.default.removeItem(at: output) }

        XCTAssertFalse(receipt.reencoded, "passthrough must not re-encode")

        // ±15% (looser than PLAN's ±10%) because shouldOptimizeForNetworkUse = true
        // reorganises atoms, which can shift the container size slightly.
        let ratio = Double(receipt.bytesOut) / Double(receipt.bytesIn)
        XCTAssert(
            (0.85 ... 1.15).contains(ratio),
            "size drifted beyond ±15%: in=\(receipt.bytesIn) out=\(receipt.bytesOut) ratio=\(ratio)"
        )
    }
}
