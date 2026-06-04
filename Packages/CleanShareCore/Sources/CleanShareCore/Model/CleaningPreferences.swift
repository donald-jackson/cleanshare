import ImageIO

/// User-controlled toggles governing what metadata survives cleaning. Defaults
/// favour privacy: GPS, capture date, camera make/model and custom XMP are all
/// stripped unless explicitly kept. See PLAN.md §4.6.
public struct CleaningPreferences: Sendable, Equatable, Codable {
    public var keepOrientation: Bool = true
    public var keepICCProfile: Bool = true
    public var keepCaptureDate: Bool = false
    public var keepGPS: Bool = false // hard NO by default
    public var keepCameraMakeModel: Bool = false
    public var keepCustomXMP: Bool = false
    public var preserveVideoCreationDate: Bool = false
    public var livePhotoMode: LivePhotoMode = .prompt

    public init(
        keepOrientation: Bool = true,
        keepICCProfile: Bool = true,
        keepCaptureDate: Bool = false,
        keepGPS: Bool = false,
        keepCameraMakeModel: Bool = false,
        keepCustomXMP: Bool = false,
        preserveVideoCreationDate: Bool = false,
        livePhotoMode: LivePhotoMode = .prompt
    ) {
        self.keepOrientation = keepOrientation
        self.keepICCProfile = keepICCProfile
        self.keepCaptureDate = keepCaptureDate
        self.keepGPS = keepGPS
        self.keepCameraMakeModel = keepCameraMakeModel
        self.keepCustomXMP = keepCustomXMP
        self.preserveVideoCreationDate = preserveVideoCreationDate
        self.livePhotoMode = livePhotoMode
    }

    /// The set of CGImage property keys permitted to survive in cleaned output,
    /// derived from the toggles. `MetadataAuditor` uses this as the allowlist:
    /// any image property key NOT in this set is a leak.
    public func allowedKeys() -> Set<String> {
        var keys: Set<String> = []

        if self.keepOrientation {
            keys.insert(kCGImagePropertyOrientation as String)
            keys.insert(kCGImagePropertyTIFFOrientation as String)
        }
        if self.keepICCProfile {
            keys.insert(kCGImagePropertyProfileName as String)
            keys.insert(kCGImagePropertyColorModel as String)
        }
        if self.keepCaptureDate {
            keys.insert(kCGImagePropertyExifDateTimeOriginal as String)
            keys.insert(kCGImagePropertyExifDateTimeDigitized as String)
            keys.insert(kCGImagePropertyTIFFDateTime as String)
        }
        if self.keepGPS {
            keys.insert(kCGImagePropertyGPSDictionary as String)
        }
        if self.keepCameraMakeModel {
            keys.insert(kCGImagePropertyTIFFMake as String)
            keys.insert(kCGImagePropertyTIFFModel as String)
        }
        if self.keepCustomXMP {
            keys.insert(kCGImagePropertyIPTCDictionary as String)
        }

        return keys
    }
}
