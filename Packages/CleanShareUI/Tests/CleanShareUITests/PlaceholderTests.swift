import XCTest
@testable import CleanShareUI

final class PlaceholderTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(CleanShareUI.version.isEmpty)
    }
}
