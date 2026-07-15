@testable import CleanShareCore
import XCTest

/// Nightly-only fuzz coverage. For each fixture we generate bit-flipped variants
/// and feed them through the matching cleaner. A cleaner may legitimately reject
/// a corrupted input by throwing, or it may succeed — but if it succeeds it MUST
/// produce leak-free output. Silently retaining metadata on a malformed file is
/// the one outcome we treat as a bug. See PLAN.md §8.4.
///
/// Gated behind `CLEANSHARE_RUN_FUZZ` so the default `swift test` run stays fast;
/// the variants are derived from a fixed seed so any failure is reproducible.
final class FuzzTests: XCTestCase {
    private let variantsPerFixture = 50

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CLEANSHARE_RUN_FUZZ"] != nil,
            "Fuzz tests are nightly-only"
        )
    }

    /// Deterministic, reproducible PRNG (SplitMix64) so a fuzz failure can be
    /// re-run byte-for-byte from its seed.
    private struct SplitMix64: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            self.state &+= 0x9E37_79B9_7F4A_7C15
            var mixed = self.state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return mixed ^ (mixed >> 31)
        }
    }

    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "missing fixture \(name).\(ext)"
        )
    }

    /// Flips one random byte (past the first 16, to keep magic numbers intact)
    /// and writes the mutated bytes to a fresh temp file.
    private func makeVariant(
        from original: Data,
        ext: String,
        rng: inout SplitMix64
    ) throws -> URL {
        var bytes = original
        if bytes.count > 16 {
            let offset = 16 + Int(rng.next() % UInt64(bytes.count - 16))
            bytes[offset] ^= UInt8(rng.next() & 0xFF) | 1 // ensure a real change
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try bytes.write(to: url)
        return url
    }

    /// Asserts the receipt/output is leak-free. Used only on the success path.
    private func assertLeakFree(_ receipt: CleanReceipt, output: URL, kind: MediaKind) async throws {
        XCTAssertTrue(
            receipt.leakedKeys.isEmpty,
            "receipt reported leaks on fuzzed input: \(receipt.leakedKeys)"
        )
        // Video must use the async verifier — the sync `audit(kind:.mp4)` returns
        // [] unconditionally and would make this assertion vacuous.
        let leaks: [String] = switch kind {
        case .mp4, .mov, .livePhoto:
            try await MetadataAuditor.auditVideo(url: output, allowing: [])
        default:
            try MetadataAuditor.audit(url: output, kind: kind, allowing: [])
        }
        XCTAssertEqual(leaks, [], "auditor found residual metadata on fuzzed input: \(leaks)")
    }

    /// Runs `clean` over `variantsPerFixture` mutations of one fixture.
    /// A thrown error is an acceptable rejection — `ImageIOCleaner` wraps every
    /// failure as a `CleanerError`, while `AVPassthroughCleaner` may surface a
    /// raw AVFoundation `NSError` on a corrupt container. Either is fine; only a
    /// successful-but-leaky clean fails the test.
    private func fuzz(
        _ name: String,
        _ ext: String,
        kind: MediaKind,
        seed: UInt64,
        clean: (URL, URL) async throws -> CleanReceipt
    ) async throws {
        let original = try Data(contentsOf: fixtureURL(name, ext))
        var rng = SplitMix64(seed: seed)

        for variantIndex in 0 ..< self.variantsPerFixture {
            let input = try makeVariant(from: original, ext: ext, rng: &rng)
            let output = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            defer {
                try? FileManager.default.removeItem(at: input)
                try? FileManager.default.removeItem(at: output)
            }

            do {
                let receipt = try await clean(input, output)
                try await assertLeakFree(receipt, output: output, kind: kind)
            } catch {
                // Rejected the malformed input — acceptable. (See doc comment.)
                XCTAssertNotNil(error, "variant \(variantIndex) of \(name).\(ext)")
            }
        }
    }

    func testFuzzJPEGiPhoneSample() async throws {
        try await self.fuzz("iphone_sample", "jpg", kind: .jpeg, seed: 0x1) { input, output in
            try await ImageIOCleaner().clean(input: input, output: output, prefs: CleaningPreferences())
        }
    }

    func testFuzzJPEGPixelSample() async throws {
        try await self.fuzz("pixel_sample", "jpg", kind: .jpeg, seed: 0x2) { input, output in
            try await ImageIOCleaner().clean(input: input, output: output, prefs: CleaningPreferences())
        }
    }

    func testFuzzJPEGLightroom() async throws {
        try await self.fuzz("lightroom", "jpg", kind: .jpeg, seed: 0x3) { input, output in
            try await ImageIOCleaner().clean(input: input, output: output, prefs: CleaningPreferences())
        }
    }

    func testFuzzPNGTransparent() async throws {
        try await self.fuzz("transparent", "png", kind: .png, seed: 0x4) { input, output in
            try await ImageIOCleaner().clean(input: input, output: output, prefs: CleaningPreferences())
        }
    }

    func testFuzzGIFAnimated() async throws {
        try await self.fuzz("animated", "gif", kind: .gif, seed: 0x5) { input, output in
            try await ImageIOCleaner().clean(input: input, output: output, prefs: CleaningPreferences())
        }
    }

    func testFuzzH264Video() async throws {
        try await self.fuzz("h264_short", "mp4", kind: .mp4, seed: 0x6) { input, output in
            try await AVPassthroughCleaner().clean(input: input, output: output, prefs: CleaningPreferences())
        }
    }
}
