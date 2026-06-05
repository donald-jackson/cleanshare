import SwiftUI

@main
struct CleanShareApp: App {
    @StateObject private var coordinator = ShareSheetCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(self.coordinator)
                .onOpenURL { url in
                    HandoffRouter.handle(url, coordinator: self.coordinator)
                }
                .task {
                    // First-launch inbox sweep: if a previous share-extension
                    // run left a manifest behind because iOS dropped its
                    // openURL handoff, pick it up now and present the share
                    // sheet immediately.
                    HandoffRouter.applyPendingInbox(coordinator: self.coordinator)
                }
        }
        .onChange(of: self.scenePhase) { _, newPhase in
            // Foreground sweep: same as the cold-start path but for the case
            // where CleanShare was already in memory when the user tapped its
            // icon after a share-extension run.
            if newPhase == .active {
                HandoffRouter.applyPendingInbox(coordinator: self.coordinator)
            }
        }
    }
}
