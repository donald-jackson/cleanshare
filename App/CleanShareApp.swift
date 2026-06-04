import SwiftUI

@main
struct CleanShareApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    _ = HandoffRouter.handle(url)
                }
        }
    }
}
