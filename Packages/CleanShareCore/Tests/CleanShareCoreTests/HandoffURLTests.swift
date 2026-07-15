@testable import CleanShareCore
import XCTest

final class HandoffURLTests: XCTestCase {
    func testRoundTrip() {
        let token = UUID().uuidString
        let url = URL.handoff(token: token)
        XCTAssertEqual(URL.handoffToken(from: url), token)
    }

    func testRejectsForeignScheme() throws {
        let url = try XCTUnwrap(URL(string: "https://evil.com"))
        XCTAssertNil(URL.handoffToken(from: url))
    }

    func testRejectsPathTraversalToken() throws {
        // A crafted token must never become a path component in the host app's
        // inbox lookup / cleanup. Only well-formed UUIDs are accepted.
        let traversal = try XCTUnwrap(URL(string: "cleanshare://handoff?t=../../../../etc"))
        XCTAssertNil(URL.handoffToken(from: traversal))

        let nonUUID = try XCTUnwrap(URL(string: "cleanshare://handoff?t=abc-123"))
        XCTAssertNil(URL.handoffToken(from: nonUUID))
    }
}
