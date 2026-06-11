@testable import CleanShareCore
import ImageIO
import XCTest

/// Verifies that the `keepX` preferences actually re-attach the corresponding
/// field to the cleaned output. Default-prefs leak-free behaviour is covered
/// by `ImageIOCleanerTests`; this file proves the *add-back* path so that the
/// Settings toggles aren't silently dead — a regression where, e.g., a user
/// turned on "Keep GPS info" and got a stripped output anyway.
final class PreferenceAddBackTests: XCTestCase {
    private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
            "missing fixture \(name).\(ext)"
        )
    }

    private func cleanedProperties(
        fixture: (String, String),
        prefs: CleaningPreferences
    ) async throws -> [CFString: Any] {
        let input = try self.fixtureURL(fixture.0, fixture.1)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fixture.1)
        defer { try? FileManager.default.removeItem(at: output) }

        _ = try await ImageIOCleaner().clean(input: input, output: output, prefs: prefs)

        let source = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return props
    }

    // MARK: - keepGPS

    func testKeepGPSPreservesCoordinates() async throws {
        var prefs = CleaningPreferences()
        prefs.keepGPS = true

        let props = try await self.cleanedProperties(fixture: ("iphone_sample", "jpg"), prefs: prefs)
        let gps = try XCTUnwrap(
            props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
            "keepGPS=true should preserve the GPS dictionary"
        )
        XCTAssertNotNil(gps[kCGImagePropertyGPSLatitude], "GPS latitude missing after keepGPS=true")
        XCTAssertNotNil(gps[kCGImagePropertyGPSLongitude], "GPS longitude missing after keepGPS=true")
    }

    func testDefaultPrefsStripGPS() async throws {
        let props = try await self.cleanedProperties(
            fixture: ("iphone_sample", "jpg"),
            prefs: CleaningPreferences()
        )
        XCTAssertNil(
            props[kCGImagePropertyGPSDictionary],
            "default prefs must strip GPS — privacy hard-no"
        )
    }

    // MARK: - keepCameraMakeModel

    func testKeepCameraMakeModelPreservesMakeAndModel() async throws {
        var prefs = CleaningPreferences()
        prefs.keepCameraMakeModel = true

        let props = try await self.cleanedProperties(fixture: ("iphone_sample", "jpg"), prefs: prefs)
        let tiff = try XCTUnwrap(
            props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
            "keepCameraMakeModel=true should preserve a TIFF dict with Make/Model"
        )
        XCTAssertEqual(tiff[kCGImagePropertyTIFFMake] as? String, "Apple")
        XCTAssertEqual(tiff[kCGImagePropertyTIFFModel] as? String, "iPhone 15 Pro")
        // We deliberately only re-add Make and Model — Software / Artist /
        // Copyright are not in scope for this toggle.
        XCTAssertNil(tiff[kCGImagePropertyTIFFSoftware])
        XCTAssertNil(tiff[kCGImagePropertyTIFFArtist])
    }

    // MARK: - Defense-in-depth

    func testDefaultPrefsStripXMP() async throws {
        let props = try await self.cleanedProperties(
            fixture: ("lightroom", "jpg"),
            prefs: CleaningPreferences()
        )
        XCTAssertNil(props["{XMP}" as CFString], "default prefs must strip XMP")
    }
}
