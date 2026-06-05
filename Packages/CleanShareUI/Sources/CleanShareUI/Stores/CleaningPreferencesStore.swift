import CleanShareCore
import Combine
import Foundation

/// `ObservableObject` backing the Settings and onboarding screens. Persists the
/// user's cleaning toggles to the App Group `UserDefaults` suite so the host app
/// and share extension share one source of truth. See PLAN.md §4.5, §4.6.
@MainActor
public final class CleaningPreferencesStore: ObservableObject {
    /// App Group suite shared between host app and share extension.
    public static let suiteName = "group.solutions.ddj.cleanshare"

    private enum Key {
        static let keepOrientation = "keepOrientation"
        static let keepICCProfile = "keepICCProfile"
        static let keepCaptureDate = "keepCaptureDate"
        static let keepGPS = "keepGPS"
        static let keepCameraMakeModel = "keepCameraMakeModel"
        static let keepCustomXMP = "keepCustomXMP"
        static let preserveVideoCreationDate = "preserveVideoCreationDate"
        static let livePhotoMode = "livePhotoMode"
        static let onboardingCompletedV1 = "onboardingCompletedV1"
        static let livePhotoDefaultMode = "LivePhotoDefaultMode"
    }

    private let defaults: UserDefaults

    @Published public var keepOrientation: Bool
    @Published public var keepICCProfile: Bool
    @Published public var keepCaptureDate: Bool
    @Published public var keepGPS: Bool
    @Published public var keepCameraMakeModel: Bool
    @Published public var keepCustomXMP: Bool
    @Published public var preserveVideoCreationDate: Bool
    @Published public var livePhotoMode: LivePhotoMode

    /// Whether the user has finished the v1 onboarding flow.
    @Published public var onboardingCompletedV1: Bool

    /// The remembered Live Photo handling default, or `nil` to keep prompting.
    @Published public var livePhotoDefaultMode: LivePhotoMode?

    private var cancellables: Set<AnyCancellable> = []

    /// Creates a store backed by the App Group suite (or `.standard` if the
    /// suite is unavailable, e.g. in unit tests without an entitlement). Pass an
    /// explicit `UserDefaults` to target a specific suite in tests.
    public init(defaults: UserDefaults? = nil) {
        let store = defaults ?? UserDefaults(suiteName: Self.suiteName) ?? .standard
        self.defaults = store

        let fallback = CleaningPreferences()
        self.keepOrientation = store.object(forKey: Key.keepOrientation) as? Bool ?? fallback.keepOrientation
        self.keepICCProfile = store.object(forKey: Key.keepICCProfile) as? Bool ?? fallback.keepICCProfile
        self.keepCaptureDate = store.object(forKey: Key.keepCaptureDate) as? Bool ?? fallback.keepCaptureDate
        self.keepGPS = store.object(forKey: Key.keepGPS) as? Bool ?? fallback.keepGPS
        self.keepCameraMakeModel = store.object(forKey: Key.keepCameraMakeModel) as? Bool ?? fallback
            .keepCameraMakeModel
        self.keepCustomXMP = store.object(forKey: Key.keepCustomXMP) as? Bool ?? fallback.keepCustomXMP
        self.preserveVideoCreationDate = store.object(forKey: Key.preserveVideoCreationDate) as? Bool ?? fallback
            .preserveVideoCreationDate
        self.livePhotoMode = (store.string(forKey: Key.livePhotoMode))
            .flatMap(LivePhotoMode.init(rawValue:)) ?? fallback.livePhotoMode
        self.onboardingCompletedV1 = store.bool(forKey: Key.onboardingCompletedV1)
        self.livePhotoDefaultMode = (store.string(forKey: Key.livePhotoDefaultMode))
            .flatMap(LivePhotoMode.init(rawValue:))

        self.bindPersistence()
    }

    /// A snapshot of the current toggle values as a `CleaningPreferences`.
    /// Setting it updates every published property (which persists each).
    public var current: CleaningPreferences {
        get {
            CleaningPreferences(
                keepOrientation: self.keepOrientation,
                keepICCProfile: self.keepICCProfile,
                keepCaptureDate: self.keepCaptureDate,
                keepGPS: self.keepGPS,
                keepCameraMakeModel: self.keepCameraMakeModel,
                keepCustomXMP: self.keepCustomXMP,
                preserveVideoCreationDate: self.preserveVideoCreationDate,
                livePhotoMode: self.livePhotoMode
            )
        }
        set {
            self.keepOrientation = newValue.keepOrientation
            self.keepICCProfile = newValue.keepICCProfile
            self.keepCaptureDate = newValue.keepCaptureDate
            self.keepGPS = newValue.keepGPS
            self.keepCameraMakeModel = newValue.keepCameraMakeModel
            self.keepCustomXMP = newValue.keepCustomXMP
            self.preserveVideoCreationDate = newValue.preserveVideoCreationDate
            self.livePhotoMode = newValue.livePhotoMode
        }
    }

    private func bindPersistence() {
        let store = self.defaults
        self.$keepOrientation.dropFirst().sink { store.set($0, forKey: Key.keepOrientation) }
            .store(in: &self.cancellables)
        self.$keepICCProfile.dropFirst().sink { store.set($0, forKey: Key.keepICCProfile) }
            .store(in: &self.cancellables)
        self.$keepCaptureDate.dropFirst().sink { store.set($0, forKey: Key.keepCaptureDate) }
            .store(in: &self.cancellables)
        self.$keepGPS.dropFirst().sink { store.set($0, forKey: Key.keepGPS) }.store(in: &self.cancellables)
        self.$keepCameraMakeModel.dropFirst().sink { store.set($0, forKey: Key.keepCameraMakeModel) }
            .store(in: &self.cancellables)
        self.$keepCustomXMP.dropFirst().sink { store.set($0, forKey: Key.keepCustomXMP) }.store(in: &self.cancellables)
        self.$preserveVideoCreationDate.dropFirst().sink { store.set($0, forKey: Key.preserveVideoCreationDate) }
            .store(in: &self.cancellables)
        self.$livePhotoMode.dropFirst().sink { store.set($0.rawValue, forKey: Key.livePhotoMode) }
            .store(in: &self.cancellables)
        self.$onboardingCompletedV1.dropFirst().sink { store.set($0, forKey: Key.onboardingCompletedV1) }
            .store(in: &self.cancellables)
        self.$livePhotoDefaultMode.dropFirst().sink { mode in
            if let mode {
                store.set(mode.rawValue, forKey: Key.livePhotoDefaultMode)
            } else {
                store.removeObject(forKey: Key.livePhotoDefaultMode)
            }
        }.store(in: &self.cancellables)
    }
}
