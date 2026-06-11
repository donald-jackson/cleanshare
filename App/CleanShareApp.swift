import SwiftUI

@main
struct CleanShareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                    // Attach the coordinator to the notification router (so a
                    // tap on the share-ready notification routes back into
                    // the share-sheet flow), request notification permission,
                    // then sweep the App Group inbox in case a previous
                    // extension run left a manifest behind.
                    CleanShareNotificationCenter.shared.attach(coordinator: self.coordinator)
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
