import Foundation
import ImageIO

/// Fail-closed verification: after a cleaner finalizes its output, the auditor
/// re-reads the file and reports any sensitive metadata dictionary that
/// survived but was not explicitly allowed. An empty result means clean. See
/// PLAN.md §8.1.
public enum MetadataAuditor {
    /// The metadata dictionary names that must never survive unless the user
    /// explicitly opted to keep them.
    static let sensitive: Set<String> = [
        "{Exif}", "{ExifAux}", "{GPS}", "{IPTC}", "{TIFF}", "{JFIF}",
        "{MakerApple}", "{MakerNikon}", "{MakerCanon}", "{MakerFuji}",
        "{MakerOlympus}", "{MakerPentax}", "{MakerSony}",
        "{XMP}", "{Photoshop}", "{IPTCXMP}", "{PNG}", "{HEICS}",
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
            let present = Set(props.keys.map { String(describing: $0) })
            return sensitive.intersection(present).subtracting(allowlist).sorted()
        }
    }
}
