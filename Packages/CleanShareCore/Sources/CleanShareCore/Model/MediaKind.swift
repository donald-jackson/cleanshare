import UniformTypeIdentifiers

/// The media formats CleanShare recognises. See PLAN.md §4.1 for the
/// per-format cleaning strategy and lossless guarantees.
public enum MediaKind: String, Sendable, CaseIterable, Codable {
    case jpeg
    case heic
    case heif
    case png
    case gif
    case webp
    case tiff
    case dng
    case mp4
    case mov
    case livePhoto

    /// The system Uniform Type Identifier for this media kind, as a `CFString`
    /// suitable for ImageIO / CoreMedia APIs.
    public var cfType: CFString {
        switch self {
        case .jpeg: return "public.jpeg" as CFString
        case .heic: return "public.heic" as CFString
        case .heif: return "public.heif" as CFString
        case .png: return "public.png" as CFString
        case .gif: return "com.compuserve.gif" as CFString
        case .webp: return "org.webmproject.webp" as CFString
        case .tiff: return "public.tiff" as CFString
        case .dng: return "com.adobe.raw-image" as CFString
        case .mp4: return "public.mpeg-4" as CFString
        case .mov: return "com.apple.quicktime-movie" as CFString
        case .livePhoto: return "com.apple.live-photo" as CFString
        }
    }

    /// Maps an iOS 14+ `UTType` to its `MediaKind`, or `nil` if unsupported.
    public init?(uti type: UTType) {
        switch type {
        case UTType.jpeg: self = .jpeg
        case UTType.heic: self = .heic
        case UTType.heif: self = .heif
        case UTType.png: self = .png
        case UTType.gif: self = .gif
        case UTType.webP: self = .webp
        case UTType.tiff: self = .tiff
        case UTType.rawImage: self = .dng
        case UTType.mpeg4Movie: self = .mp4
        case UTType.quickTimeMovie: self = .mov
        case UTType.livePhoto: self = .livePhoto
        default: return nil
        }
    }
}
