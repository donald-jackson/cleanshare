import AVFoundation
import Foundation
import ImageIO

/// Fail-closed verification: after a cleaner finalizes its output, the auditor
/// re-reads the file and reports any sensitive metadata dictionary that
/// survived but was not explicitly allowed. An empty result means clean. See
/// PLAN.md §8.1.
public enum MetadataAuditor {
    /// Metadata dictionaries that are entirely identifying: any presence at all
    /// (unless explicitly allowed) is a leak.
    static let alwaysSensitive: Set<String> = [
        "{ExifAux}", "{GPS}", "{IPTC}", "{IPTCXMP}", "{XMP}", "{Photoshop}",
        "{MakerApple}", "{MakerNikon}", "{MakerCanon}", "{MakerFuji}",
        "{MakerOlympus}", "{MakerPentax}", "{MakerSony}",
    ]

    /// Mixed dictionaries that ImageIO unavoidably regenerates from the pixel
    /// data (colour space, dimensions, density, etc.). They are only a leak if
    /// they carry a key *beyond* this structural-safe allowlist — so a stripped
    /// JPEG's `{Exif}` of `ColorSpace`/`PixelXDimension` is clean, but a lingering
    /// `UserComment` or `DateTimeOriginal` is flagged. See PLAN.md §8.1.
    static let structuralSafeKeys: [String: Set<String>] = [
        "{Exif}": ["ColorSpace", "PixelXDimension", "PixelYDimension",
                   "ComponentsConfiguration", "ExifVersion", "FlashPixVersion", "SceneType"],
        "{TIFF}": ["Orientation", "ResolutionUnit", "XResolution", "YResolution",
                   "PhotometricInterpretation", "SamplesPerPixel", "Compression", "RowsPerStrip"],
        "{JFIF}": ["JFIFVersion", "XDensity", "YDensity", "DensityUnit", "IsProgressive"],
        "{PNG}": ["InterlaceType", "Gamma", "sRGBIntent", "Chromaticities",
                  "PixelAspectRatio", "XPixelsPerMeter", "YPixelsPerMeter"],
        "{HEICS}": ["LoopCount", "DelayTime", "UnclampedDelayTime",
                    "CanvasPixelWidth", "CanvasPixelHeight"],
    ]

    /// Re-opens `url` and returns the sorted list of sensitive metadata keys
    /// that leaked through (i.e. present in the output and not in `allowing`).
    /// QuickTime/MP4 metadata identifiers that carry identifying information.
    /// Any of these present in the cleaned output (and not in the allowlist) is a
    /// leak. The content identifier is allowed only when the caller is preserving
    /// Live Photo pairing (`.preservePairing`). See PLAN.md §4.3, §8.1.
    static let sensitiveVideoIdentifiers: Set<String> = [
        "mdta/com.apple.quicktime.location.ISO6709",
        "mdta/com.apple.quicktime.creationdate",
        "mdta/com.apple.quicktime.make",
        "mdta/com.apple.quicktime.model",
        "mdta/com.apple.quicktime.software",
        "mdta/com.apple.quicktime.content.identifier",
        "udta/\u{00A9}xyz",
    ]

    public static func audit(url: URL, kind: MediaKind, allowing allowlist: Set<String>) throws -> [String] {
        switch kind {
        case .mp4, .mov, .livePhoto:
            // Video is audited asynchronously via `auditVideo(url:allowing:)`
            // because AVFoundation metadata loading is async.
            return []
        default:
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                throw CleanerError.unreadable
            }
            guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
                return []
            }

            var leaks: [String] = []
            for (rawKey, value) in props {
                let key = String(describing: rawKey)
                if allowlist.contains(key) { continue }

                if alwaysSensitive.contains(key) {
                    leaks.append(key)
                } else if let safe = structuralSafeKeys[key] {
                    guard let dict = value as? [CFString: Any] else {
                        leaks.append(key)   // unexpected shape — fail closed
                        continue
                    }
                    let subKeys = Set(dict.keys.map { String(describing: $0) })
                    let identifying = subKeys.subtracting(safe).subtracting(allowlist)
                    if !identifying.isEmpty { leaks.append(key) }
                }
            }
            return leaks.sorted()
        }
    }

    /// Re-opens a cleaned MP4/MOV at `url` and returns the sorted list of
    /// sensitive metadata identifiers that survived. It loads the asset's
    /// `.commonMetadata` and `.metadata`, plus every track's `.metadata`, maps
    /// each `AVMetadataItem` to its `identifier?.rawValue`, and flags any in
    /// `sensitiveVideoIdentifiers` not present in `allowing`. The presence of any
    /// timed-metadata track is itself a leak. See PLAN.md §4.3, §8.1.
    public static func auditVideo(url: URL, allowing allowlist: Set<String>) async throws -> [String] {
        let asset = AVURLAsset(url: url)

        var identifiers: Set<String> = []

        let common = try await asset.load(.commonMetadata)
        let containerMetadata = try await asset.load(.metadata)
        for item in common + containerMetadata {
            identifiers.insert("\(item.identifier?.rawValue ?? "")")
        }

        let tracks = try await asset.load(.tracks)
        var hasTimedMetadataTrack = false
        for track in tracks {
            if track.mediaType == .metadata { hasTimedMetadataTrack = true }
            let trackMetadata = try await track.load(.metadata)
            for item in trackMetadata {
                identifiers.insert("\(item.identifier?.rawValue ?? "")")
            }
        }

        var leaks = sensitiveVideoIdentifiers
            .intersection(identifiers)
            .subtracting(allowlist)

        if hasTimedMetadataTrack {
            leaks.insert("timed-metadata-track")
        }

        return leaks.sorted()
    }
}
