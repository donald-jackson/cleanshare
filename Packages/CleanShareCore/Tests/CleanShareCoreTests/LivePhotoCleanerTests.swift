import AVFoundation
@testable import CleanShareCore
import ImageIO
import XCTest

/// Coverage for `LivePhotoCleaner` against a synthetic still+video pair sharing
/// the content identifier `ABC-123-DEADBEEF`. Each resolved mode is verified for
/// the surviving pairing token and for absence of any other metadata leak. See
/// PLAN.md §4.5, §8.2.
final class LivePhotoCleanerTests: XCTestCase {
    private let originalID = "ABC-123-DEADBEEF"

    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "missing fixture \(name).\(ext)"
        )
    }

    private func makeOutDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    /// Reads the Live Photo content identifier from a still's `MakerApple`
    /// dictionary (key `"17"`). ImageIO stores this in a fixed-width 36-character
    /// field and pads short values with `.`, so trailing padding is stripped to
    /// recover the logical identifier (real identifiers are 36-char UUIDs and
    /// need no padding). See PLAN.md §4.5.
    private func stillIdentifier(_ url: URL) -> String? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let maker = props[kCGImagePropertyMakerAppleDictionary] as? [AnyHashable: Any]
        else {
            return nil
        }
        for (key, value) in maker where String(describing: key) == "17" {
            return String(describing: value).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        return nil
    }

    private func videoIdentifier(_ url: URL) async throws -> String? {
        let asset = AVURLAsset(url: url)
        for item in try await asset.load(.metadata) where item.identifier == .quickTimeMetadataContentIdentifier {
            return try await item.load(.stringValue)?.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        return nil
    }

    func testDowngradeProducesOnlyStillAndDropsUUID() async throws {
        let outDir = self.makeOutDir()
        defer { try? FileManager.default.removeItem(at: outDir) }

        let result = try await LivePhotoCleaner().clean(
            still: self.fixtureURL("livephoto", "heic"),
            video: self.fixtureURL("livephoto", "mov"),
            outDir: outDir,
            mode: .downgradeToStill,
            prefs: CleaningPreferences()
        )
        XCTAssertNil(result.video, "downgrade must drop the video")

        let stillOut = outDir.appendingPathComponent("livephoto.heic")
        let videoOut = outDir.appendingPathComponent("livephoto.mov")
        XCTAssertTrue(FileManager.default.fileExists(atPath: stillOut.path), "still output missing")
        XCTAssertFalse(FileManager.default.fileExists(atPath: videoOut.path), "video must not be produced")

        XCTAssertNil(self.stillIdentifier(stillOut), "MakerApple identifier must be dropped")
        let leaks = try MetadataAuditor.audit(url: stillOut, kind: .heic, allowing: [])
        XCTAssertEqual(leaks, [], "auditor leaked: \(leaks)")
    }

    func testPreservePairingKeepsUUIDInBoth() async throws {
        let outDir = self.makeOutDir()
        defer { try? FileManager.default.removeItem(at: outDir) }

        let result = try await LivePhotoCleaner().clean(
            still: self.fixtureURL("livephoto", "heic"),
            video: self.fixtureURL("livephoto", "mov"),
            outDir: outDir,
            mode: .preservePairing,
            prefs: CleaningPreferences()
        )
        XCTAssertNotNil(result.video, "preserve must keep the video")

        let stillOut = outDir.appendingPathComponent("livephoto.heic")
        let videoOut = outDir.appendingPathComponent("livephoto.mov")

        XCTAssertEqual(self.stillIdentifier(stillOut), self.originalID, "still must keep the original UUID")
        let videoID = try await videoIdentifier(videoOut)
        XCTAssertEqual(videoID, self.originalID, "video must keep the original UUID")

        // The shared content identifier is the only metadata allowed to survive.
        let stillLeaks = try MetadataAuditor.audit(url: stillOut, kind: .heic, allowing: ["{MakerApple}"])
        XCTAssertEqual(stillLeaks, [], "still leaked: \(stillLeaks)")
        let videoLeaks = try await MetadataAuditor.auditVideo(
            url: videoOut, allowing: ["mdta/com.apple.quicktime.content.identifier"]
        )
        XCTAssertEqual(videoLeaks, [], "video leaked: \(videoLeaks)")
    }

    /// Fail-closed proof: the pairing token that `.preservePairing` deliberately
    /// re-adds is itself flagged as a leak when the caller does NOT allow it —
    /// so the allowlist gate is load-bearing, and any *other* survivor would make
    /// `cleanPair`'s post-injection audit throw.
    func testPreservedPairingTokenIsALeakUnlessExplicitlyAllowed() async throws {
        let outDir = self.makeOutDir()
        defer { try? FileManager.default.removeItem(at: outDir) }

        _ = try await LivePhotoCleaner().clean(
            still: self.fixtureURL("livephoto", "heic"),
            video: self.fixtureURL("livephoto", "mov"),
            outDir: outDir,
            mode: .preservePairing,
            prefs: CleaningPreferences()
        )
        let videoOut = outDir.appendingPathComponent("livephoto.mov")
        let leaks = try await MetadataAuditor.auditVideo(url: videoOut, allowing: [])
        XCTAssertEqual(leaks, [MetadataAuditor.livePhotoContentIdentifier])
    }

    func testRepairWithFreshIDInjectsNewUUID() async throws {
        let outDir = self.makeOutDir()
        defer { try? FileManager.default.removeItem(at: outDir) }

        let result = try await LivePhotoCleaner().clean(
            still: self.fixtureURL("livephoto", "heic"),
            video: self.fixtureURL("livephoto", "mov"),
            outDir: outDir,
            mode: .repairWithFreshID,
            prefs: CleaningPreferences()
        )
        XCTAssertNotNil(result.video, "repair must keep the video")

        let stillOut = outDir.appendingPathComponent("livephoto.heic")
        let videoOut = outDir.appendingPathComponent("livephoto.mov")

        let stillID = self.stillIdentifier(stillOut)
        let videoID = try await videoIdentifier(videoOut)
        XCTAssertNotNil(stillID, "still must carry the fresh UUID")
        XCTAssertEqual(stillID, videoID, "both sides must share the fresh UUID")
        XCTAssertNotEqual(stillID, self.originalID, "fresh UUID must differ from the original")
    }
}
