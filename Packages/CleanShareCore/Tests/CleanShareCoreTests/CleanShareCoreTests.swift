import XCTest
@testable import CleanShareCore

final class CleanShareCoreTests: XCTestCase {
    func testVersionNotEmpty() {
        XCTAssertFalse(CleanShareCore.version.isEmpty)
    }
}
