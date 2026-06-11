import CleanShareCore
import Foundation
import UIKit
import UserNotifications

/// Routes "Tap to continue sharing" notification taps from the share extension
/// back into the host app's share-sheet presentation flow.
///
/// The share extension is reachable from another app's share sheet long before
/// the user has ever opened CleanShare itself — so notification authorization
/// is requested lazily at first launch of the host app, and the share
/// extension also requests it (idempotent) the first time it tries to post.
/// If the user denies, the host app's `HandoffRouter.applyPendingInbox` still
/// picks the manifest up on next foreground.
@MainActor
final class CleanShareNotificationCenter: NSObject {
    static let shared = CleanShareNotificationCenter()

    private weak var coordinator: ShareSheetCoordinator?
    /// Token captured by a notification tap that arrived before the
    /// coordinator was attached (cold launch via notification). Replayed by
    /// `attach(coordinator:)` so the share sheet still presents.
    private var pendingToken: String?

    /// Wire the coordinator and request permission. Replays any token a
    /// cold-launch notification tap left behind.
    func attach(coordinator: ShareSheetCoordinator) {
        self.coordinator = coordinator
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
        if let token = self.pendingToken {
            self.pendingToken = nil
            self.deliver(token: token, coordinator: coordinator)
        }
    }

    private func deliver(token: String, coordinator: ShareSheetCoordinator) {
        let url = URL.handoffCustomScheme(token: token)
        _ = HandoffRouter.handle(url, coordinator: coordinator)
    }
}

extension CleanShareNotificationCenter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let token = userInfo[URL.handoffNotificationTokenKey] as? String
        Task { @MainActor in
            if let token {
                if let coordinator = self.coordinator {
                    self.deliver(token: token, coordinator: coordinator)
                } else {
                    self.pendingToken = token
                }
            }
            completionHandler()
        }
    }

    /// Foreground delivery: don't show the banner — the inbox sweep / direct
    /// route already presents the share sheet, so the banner would just be
    /// noise on top of the user's current screen.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}

/// Installed by `CleanShareApp` via `@UIApplicationDelegateAdaptor`. The only
/// job is to register the notification-center delegate as early as possible —
/// before the system delivers any queued notification tap that woke the app
/// from cold.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = CleanShareNotificationCenter.shared
        return true
    }
}
