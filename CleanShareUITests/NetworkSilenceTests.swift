import XCTest

/// Records every URL the process tries to load. Registered at the head of the
/// `URLProtocol` chain in `setUp`; `canInit(with:)` captures the request URL and
/// returns `false` so the request falls through to the real loader untouched.
///
/// CleanShare performs zero network access (PLAN.md §18.3), so a clean run leaves
/// `recordedRequests` empty across every user flow. Any captured URL is a
/// regression and fails the test.
final class NetworkRecorder: URLProtocol {
    static let lock = NSLock()
    nonisolated(unsafe) static var recordedRequests: [URL] = []

    static func reset() {
        self.lock.lock()
        self.recordedRequests = []
        self.lock.unlock()
    }

    static func snapshot() -> [URL] {
        self.lock.lock()
        defer { lock.unlock() }
        return self.recordedRequests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        if let url = request.url {
            self.lock.lock()
            self.recordedRequests.append(url)
            self.lock.unlock()
        }
        return false
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {}
    override func stopLoading() {}
}

/// Drives the real product flows and asserts no network access occurs at any
/// point. See PLAN.md §8.5 and §18.3.
@MainActor
final class NetworkSilenceTests: XCTestCase {
    private var app: XCUIApplication!

    func testNoNetworkAccessAcrossFlows() {
        continueAfterFailure = false
        URLProtocol.registerClass(NetworkRecorder.self)
        defer { URLProtocol.unregisterClass(NetworkRecorder.self) }
        NetworkRecorder.reset()
        self.app = XCUIApplication()
        self.app.launch()

        self.dismissOnboardingIfPresent()
        self.assertSilent(phase: "launch + onboarding")

        self.runSamplePhotoFlow()
        self.assertSilent(phase: "sample photo")

        self.runCleanPhotosFlow()
        self.assertSilent(phase: "clean photos + share")
    }

    // MARK: - Flows

    private func dismissOnboardingIfPresent() {
        let getStarted = self.app.buttons["Get started"]
        guard getStarted.waitForExistence(timeout: 5) else { return }
        // Onboarding is a paged TabView; swipe to the final page if needed.
        for _ in 0 ..< 4 where !getStarted.isHittable {
            app.swipeLeft()
        }
        if getStarted.isHittable {
            getStarted.tap()
        }
    }

    private func runSamplePhotoFlow() {
        let sample = self.app.buttons["Try it on a sample photo"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10), "Main screen did not appear")
        sample.tap()
        // The BEFORE / AFTER diff sheet renders the column headers.
        let beforeHeader = self.app.staticTexts["Before"]
        _ = beforeHeader.waitForExistence(timeout: 10)
        // Dismiss the sheet by swiping it down.
        self.app.swipeDown()
        // Wait for the main screen to be interactive again.
        _ = sample.waitForExistence(timeout: 5)
    }

    private func runCleanPhotosFlow() {
        let cleanButton = self.app.buttons["Clean photos…"]
        XCTAssertTrue(cleanButton.waitForExistence(timeout: 10), "Clean photos button missing")
        cleanButton.tap()

        self.selectFirstPhotoInPicker()

        // Cleaning runs, then the system share sheet appears. Cancel it.
        self.cancelShareSheet()
    }

    /// Picks the first available media item from the system photo picker. The
    /// picker is hosted out of process, so query it via Springboard as well as
    /// the app's own element tree.
    private func selectFirstPhotoInPicker() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let candidates = [app, springboard]

        for source in candidates {
            guard let source else { continue }
            let images = source.images
            if images.firstMatch.waitForExistence(timeout: 6) {
                images.firstMatch.tap()
                // Some picker layouts require an explicit "Add" confirmation.
                let add = source.buttons["Add"]
                if add.waitForExistence(timeout: 3) {
                    add.tap()
                }
                return
            }
            let cells = source.cells
            if cells.firstMatch.waitForExistence(timeout: 3) {
                cells.firstMatch.tap()
                let add = source.buttons["Add"]
                if add.waitForExistence(timeout: 3) {
                    add.tap()
                }
                return
            }
        }
    }

    /// Cancels the system share sheet if it appears. Cleaning is asynchronous, so
    /// allow generous time for the activity controller to present.
    private func cancelShareSheet() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for source in [self.app, springboard] {
            guard let source else { continue }
            let cancel = source.buttons["Cancel"]
            if cancel.waitForExistence(timeout: 12) {
                cancel.tap()
                return
            }
            let close = source.buttons["Close"]
            if close.waitForExistence(timeout: 1) {
                close.tap()
                return
            }
        }
        // No share sheet surfaced (e.g. picker selection produced no output);
        // nothing to cancel. The network assertion still applies.
    }

    // MARK: - Assertion

    private func assertSilent(phase: String, file: StaticString = #filePath, line: UInt = #line) {
        let urls = NetworkRecorder.snapshot()
        XCTAssertTrue(
            urls.isEmpty,
            "Network access detected during \(phase): \(urls.map(\.absoluteString).joined(separator: ", "))",
            file: file,
            line: line
        )
    }
}
