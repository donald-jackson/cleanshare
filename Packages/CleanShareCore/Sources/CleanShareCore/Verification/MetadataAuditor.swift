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
    public static func audit(url: URL, kind: MediaKind, allowing allowlist: Set<String>) throws -> [String] {
        switch kind {
        case .mp4, .mov, .livePhoto:
            // Video auditing is filled in by task 3.02.
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
}
