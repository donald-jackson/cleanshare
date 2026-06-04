import Foundation

public enum CleanerError: Error, Sendable, Equatable {
    case unreadable
    case unwritable
    case frameDecodeFailed(index: Int)
    case writeFailed
    case leakDetected(keys: [String])
    case appendFailed
    case avFailed(reason: String?)
    case unsupportedFormat(String)
    case cancelled
}
