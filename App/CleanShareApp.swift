import SwiftUI

@main
struct CleanShareApp: App {
    @StateObject private var coordinator = ShareSheetCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .onOpenURL { url in
                    HandoffRouter.handle(url, coordinator: coordinator)
                }
        }
    }
}
