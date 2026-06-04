@testable import CleanShareCore
import XCTest

final class CleanShareCoreTests: XCTestCase {
    func testVersionNotEmpty() {
        XCTAssertFalse(CleanShareCore.version.isEmpty)
    }
}
