import CleanShareCore
@testable import CleanShareUI
import XCTest

@MainActor
final class CleaningPreferencesStoreTests: XCTestCase {
    func testPersistenceRoundTrip() throws {
        let suiteName = "CleaningPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = CleaningPreferencesStore(defaults: defaults)

        // Default is keepGPS == false; flip it and a couple of others.
        XCTAssertFalse(store.keepGPS)
        store.keepGPS = true
        store.keepCaptureDate = true
        store.livePhotoDefaultMode = .repairWithFreshID
        store.onboardingCompletedV1 = true

        // Re-init from the same suite and confirm the values persisted.
        let reloaded = CleaningPreferencesStore(defaults: defaults)
        XCTAssertTrue(reloaded.keepGPS)
        XCTAssertTrue(reloaded.keepCaptureDate)
        XCTAssertEqual(reloaded.livePhotoDefaultMode, .repairWithFreshID)
        XCTAssertTrue(reloaded.onboardingCompletedV1)

        // Snapshot reflects the mutated values.
        XCTAssertTrue(reloaded.current.keepGPS)
        XCTAssertTrue(reloaded.current.keepCaptureDate)
    }
}
