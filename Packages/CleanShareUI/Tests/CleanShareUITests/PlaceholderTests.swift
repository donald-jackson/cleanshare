@testable import CleanShareUI
import XCTest

final class PlaceholderTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(CleanShareUI.version.isEmpty)
    }
}
