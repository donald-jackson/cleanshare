@testable import CleanShareCore
import XCTest

/// Coverage for the App-Group preferences reader the share extension uses so it
/// honours the user's saved Settings instead of always cleaning with defaults.
final class CleaningPreferencesLoadTests: XCTestCase {
    private func makeDefaults() throws -> UserDefaults {
        let suite = "test.cleanshare.prefs.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    func testLoadReturnsPrivacyFirstDefaultsWhenNothingSaved() throws {
        let prefs = try CleaningPreferences.load(from: self.makeDefaults())
        XCTAssertEqual(prefs, CleaningPreferences())
        XCTAssertFalse(prefs.keepGPS)
        XCTAssertFalse(prefs.keepCaptureDate)
    }

    func testLoadReflectsSavedToggles() throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: CleaningPreferences.DefaultsKey.keepCaptureDate)
        defaults.set(true, forKey: CleaningPreferences.DefaultsKey.keepCameraMakeModel)
        defaults.set(false, forKey: CleaningPreferences.DefaultsKey.keepOrientation)
        defaults.set(LivePhotoMode.repairWithFreshID.rawValue, forKey: CleaningPreferences.DefaultsKey.livePhotoMode)

        let prefs = CleaningPreferences.load(from: defaults)
        XCTAssertTrue(prefs.keepCaptureDate)
        XCTAssertTrue(prefs.keepCameraMakeModel)
        XCTAssertFalse(prefs.keepOrientation)
        XCTAssertEqual(prefs.livePhotoMode, .repairWithFreshID)
        // Untouched key keeps its privacy-first default.
        XCTAssertFalse(prefs.keepGPS)
    }
}
