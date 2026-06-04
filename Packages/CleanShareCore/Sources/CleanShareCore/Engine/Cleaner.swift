import Foundation

/// A metadata-stripping cleaner for a single media file.
public protocol Cleaner: Sendable {
    func clean(input: URL, output: URL, prefs: CleaningPreferences) async throws -> CleanReceipt
}
