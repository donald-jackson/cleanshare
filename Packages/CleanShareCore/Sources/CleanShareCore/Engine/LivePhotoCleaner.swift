import AVFoundation
import CoreMedia
import Foundation
import ImageIO

/// Cleans a Live Photo — a still (HEIC/JPEG) paired with a motion video (MOV) by
/// a shared content-identifier UUID. The still carries the UUID in its
/// `MakerApple` dictionary under key `"17"`; the video carries it as an
/// `AVMetadataItem` with identifier `mdta/com.apple.quicktime.content.identifier`.
///
/// The three resolved modes trade privacy against the surviving pairing token.
/// The engine never receives `.prompt` — the UI resolves it first. See PLAN.md §4.5.
public struct LivePhotoCleaner: Sendable {
    public init() {}

    public func clean(
        still: URL,
        video: URL,
        outDir: URL,
        mode: LivePhotoMode,
        prefs: CleaningPreferences
    ) async throws -> (still: CleanReceipt, video: CleanReceipt?) {
        guard mode != .prompt else {
            throw CleanerError.unsupportedFormat("LivePhotoMode.prompt must be resolved by UI")
        }

        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let stillOut = outDir.appendingPathComponent(still.lastPathComponent)
        let videoOut = outDir.appendingPathComponent(video.lastPathComponent)

        switch mode {
        case .prompt:
            // Unreachable — guarded above.
            throw CleanerError.unsupportedFormat("LivePhotoMode.prompt must be resolved by UI")

        case .downgradeToStill:
            // Clean only the still and drop the pairing entirely. ImageIOCleaner
            // already nulls MakerApple, so no identifier survives.
            let receipt = try await ImageIOCleaner().clean(input: still, output: stillOut, prefs: prefs)
            return (receipt, nil)

        case .preservePairing:
            // Reuse the original shared UUID on both sides.
            var originalID = self.readStillIdentifier(from: still)
            if originalID == nil {
                originalID = try await self.readVideoIdentifier(from: video)
            }
            return try await self.cleanPair(
                still: still, stillOut: stillOut,
                video: video, videoOut: videoOut,
                identifier: originalID ?? UUID().uuidString, prefs: prefs
            )

        case .repairWithFreshID:
            // Sever correlation with the source assets via a brand-new shared UUID.
            let freshID = UUID().uuidString
            return try await self.cleanPair(
                still: still, stillOut: stillOut,
                video: video, videoOut: videoOut,
                identifier: freshID, prefs: prefs
            )
        }
    }

    private func cleanPair(
        still: URL, stillOut: URL,
        video: URL, videoOut: URL,
        identifier: String,
        prefs: CleaningPreferences
    ) async throws -> (still: CleanReceipt, video: CleanReceipt?) {
        let stillReceipt = try await ImageIOCleaner().clean(input: still, output: stillOut, prefs: prefs)
        try self.injectStillIdentifier(identifier, into: stillOut)

        let videoReceipt = try await AVPassthroughCleaner().clean(input: video, output: videoOut, prefs: prefs)
        try self.injectContentIdentifier(identifier, into: videoOut)

        return (stillReceipt, videoReceipt)
    }

    // MARK: - UUID reads

    private func readStillIdentifier(from still: URL) -> String? {
        guard let src = CGImageSourceCreateWithURL(still as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let maker = props[kCGImagePropertyMakerAppleDictionary] as? [AnyHashable: Any]
        else {
            return nil
        }
        for (key, value) in maker where String(describing: key) == "17" {
            return String(describing: value)
        }
        return nil
    }

    private func readVideoIdentifier(from video: URL) async throws -> String? {
        let asset = AVURLAsset(url: video)
        let metadata = try await asset.load(.metadata)
        for item in metadata where item.identifier == .quickTimeMetadataContentIdentifier {
            return try await item.load(.stringValue)
        }
        return nil
    }

    // MARK: - UUID injection

    /// Re-adds the Live Photo content identifier to a cleaned still by writing a
    /// fresh `MakerApple` dictionary containing only key `"17"`. The base file was
    /// already verified clean by `ImageIOCleaner`; this re-introduces a single
    /// allowed key. See PLAN.md §4.5.
    func injectStillIdentifier(_ id: String, into stillURL: URL) throws {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(stillURL as CFURL, srcOpts) else {
            throw CleanerError.unreadable
        }
        let type = CGImageSourceGetType(src) ?? MediaKind.heic.cfType
        let count = max(CGImageSourceGetCount(src), 1)
        guard let cgImage = CGImageSourceCreateImageAtIndex(src, 0, srcOpts) else {
            throw CleanerError.frameDecodeFailed(index: 0)
        }

        var props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]) ?? [:]
        props[kCGImagePropertyMakerAppleDictionary] = ["17": id]

        let tmpURL = stillURL.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(stillURL.pathExtension.isEmpty ? "heic" : stillURL.pathExtension)
        guard let dest = CGImageDestinationCreateWithURL(tmpURL as CFURL, type, count, nil) else {
            throw CleanerError.unwritable
        }
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary) // NOT AddImageFromSource
        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: tmpURL)
            throw CleanerError.writeFailed
        }
        _ = try FileManager.default.replaceItemAt(stillURL, withItemAt: tmpURL)
    }

    /// Re-adds the QuickTime content identifier to a cleaned video by re-muxing it
    /// through `AVAssetExportSession` passthrough (no re-encode) with the identifier
    /// in the container metadata, then atomically replacing the original. The
    /// passthrough preset preserves the compressed streams losslessly. See PLAN.md §4.5.
    func injectContentIdentifier(_ id: String, into videoURL: URL) throws {
        let asset = AVURLAsset(url: videoURL)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw CleanerError.avFailed(reason: "could not create passthrough export session")
        }

        let isMOV = videoURL.pathExtension.lowercased() == "mov"
        let tmpURL = videoURL.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(videoURL.pathExtension.isEmpty ? "mov" : videoURL.pathExtension)

        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataContentIdentifier
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        item.value = id as NSString

        export.outputURL = tmpURL
        export.outputFileType = isMOV ? .mov : .mp4
        export.metadata = [item]

        let semaphore = DispatchSemaphore(value: 0)
        export.exportAsynchronously { semaphore.signal() }
        semaphore.wait()

        guard export.status == .completed else {
            try? FileManager.default.removeItem(at: tmpURL)
            throw CleanerError.avFailed(reason: export.error?.localizedDescription)
        }
        _ = try FileManager.default.replaceItemAt(videoURL, withItemAt: tmpURL)
    }
}
