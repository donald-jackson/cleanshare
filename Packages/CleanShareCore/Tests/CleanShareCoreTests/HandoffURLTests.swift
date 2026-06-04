@testable import CleanShareCore
import XCTest

final class HandoffURLTests: XCTestCase {
    func testRoundTrip() {
        let token = "abc-123"
        let url = URL.handoff(token: token)
        XCTAssertEqual(URL.handoffToken(from: url), token)
    }

    func testRejectsForeignScheme() throws {
        let url = try XCTUnwrap(URL(string: "https://evil.com"))
        XCTAssertNil(URL.handoffToken(from: url))
    }
}
