import XCTest
@testable import CleanShareCore

final class MemoryWatchdogTests: XCTestCase {
    func testMemoryWatchdogBasicTest() async {
        let watchdog = MemoryWatchdog()
        let mb = await watchdog.footprintMB()
        XCTAssertGreaterThan(mb, 0)
    }
}
