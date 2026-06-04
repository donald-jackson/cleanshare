@testable import CleanShareCore
import XCTest

final class MemoryWatchdogTests: XCTestCase {
    func testMemoryWatchdogBasicTest() async {
        let watchdog = MemoryWatchdog()
        let megabytes = await watchdog.footprintMB()
        XCTAssertGreaterThan(megabytes, 0)
    }
}
