import SwiftUI
import UserNotifications
#if os(iOS)
import UIKit
#endif

/// First-run onboarding flow: paged `TabView` that introduces the app, explains
/// the share flow, states the privacy posture, and then asks for notification
/// permission — the only way CleanShare can tell the user "your photos are
/// cleaned and ready to share" once the share-extension UI dismisses itself.
/// See PLAN.md §14.2.
public struct OnboardingView: View {
    @ObservedObject private var prefsStore: CleaningPreferencesStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var selection: Int = 0
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var requestInFlight: Bool = false

    /// Teal → indigo brand gradient (PLAN.md §14.2).
    private static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.098, green: 0.706, blue: 0.690),
            Color(red: 0.231, green: 0.247, blue: 0.722)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private static let teal = Color(red: 0.098, green: 0.706, blue: 0.690)
    private static let indigo = Color(red: 0.231, green: 0.247, blue: 0.722)

    private static let notificationsPageIndex = 3

    public init(prefsStore: CleaningPreferencesStore) {
        self.prefsStore = prefsStore
    }

    public var body: some View {
        self.pagedTabView
            .ignoresSafeArea()
            .task { await self.refreshNotificationStatus() }
            .onChange(of: self.scenePhase) { _, newPhase in
                // User may have flipped the Notifications toggle in Settings
                // and come back. Re-check so we can let them through.
                if newPhase == .active {
                    Task { await self.refreshNotificationStatus() }
                }
            }
    }

    @ViewBuilder
    private var pagedTabView: some View {
        let tabs = TabView(selection: $selection) {
            self.welcomePage.tag(0)
            self.howPage.tag(1)
            self.privacyPage.tag(2)
            self.notificationsPage.tag(Self.notificationsPageIndex)
        }
        #if os(iOS)
        tabs
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        #else
        tabs
        #endif
    }

    private var welcomePage: some View {
        self.page {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 84))
                .foregroundStyle(Self.teal)
                .padding(28)
                .background(.white, in: Circle())
            Text("Share without leaking")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("CleanShare strips identifying metadata from your photos and videos before sharing them")
                .font(.title3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var howPage: some View {
        self.page {
            Text("How it works")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 28) {
                self.step(number: 1, symbol: "square.and.arrow.up", text: "Share from Photos")
                self.step(number: 2, symbol: "wand.and.stars", text: "CleanShare cleans")
                self.step(number: 3, symbol: "paperplane.fill", text: "Share to anyone")
            }
        }
    }

    private var privacyPage: some View {
        self.page {
            Text("Private by design")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 16) {
                self.bullet("No accounts.")
                self.bullet("No analytics.")
                self.bullet("No network.")
                self.bullet("Source open at github.com/donald-jackson/cleanshare.")
            }
            Button {
                withAnimation { self.selection = Self.notificationsPageIndex }
            } label: {
                self.whitePillLabel(text: "Continue", systemImage: "arrow.right")
            }
            .padding(.top, 12)
        }
    }

    private var notificationsPage: some View {
        self.page {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 84))
                .foregroundStyle(Self.teal)
                .padding(28)
                .background(.white, in: Circle())
            Text("One quick step")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(
                "CleanShare sends one notification per share — to tell you your photos are cleaned and ready to forward. That's the only thing notifications are ever used for."
            )
            .font(.callout)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(.white.opacity(0.92))

            if self.notificationStatus == .denied {
                Text(
                    "Notifications are turned off for CleanShare. The app can't tell you when your share is ready without them — please enable them in Settings to continue."
                )
                .font(.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 4)
                Button {
                    self.openSystemSettings()
                } label: {
                    self.whitePillLabel(text: "Open Settings", systemImage: "gear")
                }
            } else {
                Button {
                    self.requestNotificationPermission()
                } label: {
                    self.whitePillLabel(text: "Allow notifications", systemImage: "bell.fill")
                }
                .disabled(self.requestInFlight)
                .opacity(self.requestInFlight ? 0.5 : 1.0)
            }
        }
    }

    private func step(number: Int, symbol: String, text: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 32))
                .frame(width: 44)
            Text("\(number). \(text)")
                .font(.title3.weight(.medium))
        }
        .foregroundStyle(.white)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
            Text(text)
        }
        .font(.title3)
        .foregroundStyle(.white)
    }

    private func whitePillLabel(text: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(Self.indigo)
    }

    private func page(@ViewBuilder _ content: () -> some View) -> some View {
        ZStack {
            Self.brandGradient.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                content()
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 64)
            .foregroundStyle(.white)
        }
    }

    // MARK: - Notification permission

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.notificationStatus = settings.authorizationStatus
        // If the user enabled notifications via Settings and came back to the
        // app while sitting on the notifications page, finish onboarding.
        if settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional,
            self.selection == Self.notificationsPageIndex {
            self.complete()
        }
    }

    private func requestNotificationPermission() {
        guard !self.requestInFlight else { return }
        self.requestInFlight = true
        Task {
            let granted = await (try? UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])) ?? false
            await self.refreshNotificationStatus()
            self.requestInFlight = false
            if granted {
                self.complete()
            }
        }
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            self.openURL(url)
        }
        #endif
    }

    private func complete() {
        self.prefsStore.onboardingCompletedV1 = true
        self.dismiss()
    }
}
