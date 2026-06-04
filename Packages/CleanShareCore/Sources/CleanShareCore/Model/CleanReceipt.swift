import Foundation

/// The result of cleaning a single media item. See PLAN.md §4.6. `leakedKeys`
/// is empty on success; a non-empty list means the auditor found residual
/// metadata the pipeline failed to strip.
public struct CleanReceipt: Sendable, Codable, Equatable {
    public let inputURL: URL
    public let outputURL: URL
    public let kind: MediaKind
    public let bytesIn: Int
    public let bytesOut: Int
    public let durationMS: Int
    public let reencoded: Bool
    public let leakedKeys: [String]

    public init(
        inputURL: URL,
        outputURL: URL,
        kind: MediaKind,
        bytesIn: Int,
        bytesOut: Int,
        durationMS: Int,
        reencoded: Bool,
        leakedKeys: [String]
    ) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.kind = kind
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.durationMS = durationMS
        self.reencoded = reencoded
        self.leakedKeys = leakedKeys
    }
}
