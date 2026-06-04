import SwiftUI

/// First-run onboarding flow: a three-page paged `TabView` that introduces the
/// app, explains the share flow, and states the privacy posture before handing
/// off to the main UI. See PLAN.md §14.2.
public struct OnboardingView: View {
    @ObservedObject private var prefsStore: CleaningPreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int = 0

    /// Teal → indigo brand gradient (PLAN.md §14.2).
    private static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.098, green: 0.706, blue: 0.690),
            Color(red: 0.231, green: 0.247, blue: 0.722)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    public init(prefsStore: CleaningPreferencesStore) {
        self.prefsStore = prefsStore
    }

    public var body: some View {
        pagedTabView
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var pagedTabView: some View {
        let tabs = TabView(selection: $selection) {
            welcomePage.tag(0)
            howPage.tag(1)
            privacyPage.tag(2)
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
        page {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 84))
                .foregroundStyle(Color(red: 0.098, green: 0.706, blue: 0.690))
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
        page {
            Text("How it works")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 28) {
                step(number: 1, symbol: "square.and.arrow.up", text: "Share from Photos")
                step(number: 2, symbol: "wand.and.stars", text: "CleanShare cleans")
                step(number: 3, symbol: "paperplane.fill", text: "Share to anyone")
            }
        }
    }

    private var privacyPage: some View {
        page {
            Text("Private by design")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 16) {
                bullet("No accounts.")
                bullet("No analytics.")
                bullet("No network.")
                bullet("Source open at github.com/<placeholder>/cleanshare.")
            }
            Button {
                prefsStore.onboardingCompletedV1 = true
                dismiss()
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color(red: 0.231, green: 0.247, blue: 0.722))
            }
            .padding(.top, 12)
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

    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
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
}
