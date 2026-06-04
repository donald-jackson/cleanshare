import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Strips metadata from still images (and animated/multi-frame formats) using
/// the canonical ImageIO safe pattern: extract each frame as a `CGImage` and
/// re-add it with a fully sanitized property dictionary via
/// `CGImageDestinationAddImage`. The from-source variant is deliberately avoided
/// because it silently carries the source's metadata. See PLAN.md §4.2.
public struct ImageIOCleaner: Cleaner {
    public init() {}

    public func clean(input: URL, output: URL, prefs: CleaningPreferences) async throws -> CleanReceipt {
        let start = DispatchTime.now()

        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(input as CFURL, srcOpts) else {
            throw CleanerError.unreadable
        }

        let frameCount = CGImageSourceGetCount(src)
        let utType = CGImageSourceGetType(src)
        let kind = utType
            .flatMap { UTType($0 as String) }
            .flatMap { MediaKind(uti: $0) } ?? .jpeg
        let destType = utType ?? kind.cfType

        guard let dest = CGImageDestinationCreateWithURL(output as CFURL, destType, frameCount, nil) else {
            throw CleanerError.unwritable
        }

        if let containerProps = sanitizedContainerProperties(from: src, prefs: prefs) {
            CGImageDestinationSetProperties(dest, containerProps as CFDictionary)
        }

        for i in 0..<frameCount {
            try Task.checkCancellation()
            guard let cgImage = CGImageSourceCreateImageAtIndex(src, i, srcOpts) else {
                throw CleanerError.frameDecodeFailed(index: i)
            }
            let props = sanitizedFrameProperties(from: src, frameIndex: i, prefs: prefs)
            CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)   // NOT AddImageFromSource
        }

        guard CGImageDestinationFinalize(dest) else { throw CleanerError.writeFailed }

        let leaked = try MetadataAuditor.audit(url: output, kind: kind, allowing: prefs.allowedKeys())
        guard leaked.isEmpty else { throw CleanerError.leakDetected(keys: leaked) }

        let bytesIn = fileSize(at: input)
        let bytesOut = fileSize(at: output)
        let elapsedMS = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)

        return CleanReceipt(
            inputURL: input,
            outputURL: output,
            kind: kind,
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            durationMS: elapsedMS,
            reencoded: true,
            leakedKeys: []
        )
    }

    private func fileSize(at url: URL) -> Int {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize ?? 0
    }
}
