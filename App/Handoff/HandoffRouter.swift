import Foundation

enum HandoffRouter {
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        // Real implementation comes in task 3.13. For now, accept any
        // cleanshare:// URL silently so the app does not crash.
        return url.scheme == "cleanshare"
    }
}
