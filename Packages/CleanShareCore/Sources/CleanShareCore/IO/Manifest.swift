import Foundation

/// Describes the output of one cleaning job: the handoff token, when it was
/// produced, and a receipt per cleaned item. Serialized into the App Group
/// workspace so the host app can present results after the extension hands off.
/// See PLAN.md §6.
public struct Manifest: Codable, Sendable, Equatable {
    public let token: String
    public let createdAt: Date
    public let receipts: [CleanReceipt]

    public init(token: String, receipts: [CleanReceipt]) {
        self.token = token
        self.createdAt = Date()
        self.receipts = receipts
    }
}

public enum ManifestWriter {
    public static func write(_ manifest: Manifest, to url: URL) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: url, options: .atomic)
    }
}

public enum ManifestReader {
    public static func read(from url: URL) throws -> Manifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Manifest.self, from: data)
    }
}
