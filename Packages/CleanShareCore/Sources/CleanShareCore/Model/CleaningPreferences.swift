import Foundation
import ImageIO

/// User-controlled toggles governing what metadata survives cleaning. Defaults
/// favour privacy: GPS, capture date, camera make/model and custom XMP are all
/// stripped unless explicitly kept. See PLAN.md §4.6.
public struct CleaningPreferences: Sendable, Equatable, Codable {
    /// App Group suite the host app and share extension share preferences through.
    public static let appGroupSuiteName = "group.solutions.ddj.cleanshare"

    /// `UserDefaults` keys, kept in lockstep with `CleaningPreferencesStore`.
    /// A round-trip test (`ExtensionPreferencesTests`) pins these together so the
    /// two readers cannot silently drift apart.
    public enum DefaultsKey {
        public static let keepOrientation = "keepOrientation"
        public static let keepICCProfile = "keepICCProfile"
        public static let keepCaptureDate = "keepCaptureDate"
        public static let keepGPS = "keepGPS"
        public static let keepCameraMakeModel = "keepCameraMakeModel"
        public static let keepCustomXMP = "keepCustomXMP"
        public static let preserveVideoCreationDate = "preserveVideoCreationDate"
        public static let livePhotoMode = "livePhotoMode"
    }

    /// Reconstructs the user's saved preferences from a `UserDefaults` suite,
    /// falling back to the privacy-first defaults for any key never written.
    /// Used by the share extension so its cleaning honours the same Settings the
    /// host app does — instead of silently always using defaults.
    public static func load(from defaults: UserDefaults) -> CleaningPreferences {
        let fallback = CleaningPreferences()
        func flag(_ key: String, _ fallbackValue: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fallbackValue
        }
        return CleaningPreferences(
            keepOrientation: flag(DefaultsKey.keepOrientation, fallback.keepOrientation),
            keepICCProfile: flag(DefaultsKey.keepICCProfile, fallback.keepICCProfile),
            keepCaptureDate: flag(DefaultsKey.keepCaptureDate, fallback.keepCaptureDate),
            keepGPS: flag(DefaultsKey.keepGPS, fallback.keepGPS),
            keepCameraMakeModel: flag(DefaultsKey.keepCameraMakeModel, fallback.keepCameraMakeModel),
            keepCustomXMP: flag(DefaultsKey.keepCustomXMP, fallback.keepCustomXMP),
            preserveVideoCreationDate: flag(DefaultsKey.preserveVideoCreationDate, fallback.preserveVideoCreationDate),
            livePhotoMode: defaults.string(forKey: DefaultsKey.livePhotoMode)
                .flatMap(LivePhotoMode.init(rawValue:)) ?? fallback.livePhotoMode
        )
    }

    /// Loads the preferences saved in the shared App Group suite (or the
    /// privacy-first defaults if the suite is unavailable).
    public static func loadFromAppGroup(
        suiteName: String = CleaningPreferences.appGroupSuiteName
    ) -> CleaningPreferences {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return CleaningPreferences() }
        return self.load(from: defaults)
    }

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
