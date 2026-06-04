@testable import CleanShareCore
import XCTest

final class ManifestTests: XCTestCase {
    func testRoundTrip() throws {
        let receipt = CleanReceipt(
            inputURL: URL(fileURLWithPath: "/tmp/in.jpg"),
            outputURL: URL(fileURLWithPath: "/tmp/out.jpg"),
            kind: .jpeg,
            bytesIn: 1024,
            bytesOut: 768,
            durationMS: 42,
            reencoded: false,
            leakedKeys: []
        )
        let manifest = Manifest(token: "abc-123", receipts: [receipt])

        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("manifest-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try ManifestWriter.write(manifest, to: url)
        let decoded = try ManifestReader.read(from: url)

        XCTAssertEqual(decoded, manifest)
    }
}
