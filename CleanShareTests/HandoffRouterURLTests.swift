import CleanShareCore
import XCTest

/// Host-app coverage for the two handoff URL forms `HandoffRouter` accepts:
/// the Universal Link (`https://cleanshare.dev/handoff?t=…`) and the custom
/// scheme (`cleanshare://handoff?t=…`). Both must resolve to the same token so
/// the router behaves identically whichever path the extension's `open()` ladder
/// succeeds on. See PLAN.md §6.3.
final class HandoffRouterURLTests: XCTestCase {
    func testUniversalLinkAndCustomSchemeYieldSameToken() {
        let token = "9C2F1A40-DEAD-BEEF-0000-000000000001"

        let universal = URL.handoff(token: token)
        let custom = URL.handoffCustomScheme(token: token)

        XCTAssertEqual(universal.scheme, "https")
        XCTAssertEqual(universal.host, "cleanshare.dev")
        XCTAssertEqual(custom.scheme, "cleanshare")

        XCTAssertEqual(URL.handoffToken(from: universal), token)
        XCTAssertEqual(URL.handoffToken(from: custom), token)
        XCTAssertEqual(URL.handoffToken(from: universal), URL.handoffToken(from: custom))
    }

    func testRejectsForeignHTTPSHost() throws {
        let url = try XCTUnwrap(URL(string: "https://evil.example/handoff?t=abc"))
        XCTAssertNil(URL.handoffToken(from: url))
    }

    func testRejectsWrongHTTPSPath() throws {
        let url = try XCTUnwrap(URL(string: "https://cleanshare.dev/login?t=abc"))
        XCTAssertNil(URL.handoffToken(from: url))
    }
}
