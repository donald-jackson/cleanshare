import CleanShareUI
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var coordinator: ShareSheetCoordinator
    @StateObject private var prefsStore = CleaningPreferencesStore()

    var body: some View {
        VStack(spacing: 16) {
            Text("CleanShare")
                .font(.largeTitle).bold()
            Text("Strip metadata before sharing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView(prefsStore: prefsStore)
        }
        .sheet(isPresented: shareSheetBinding) {
            if let urls = coordinator.pendingURLs {
                ActivityView(activityItems: urls) {
                    coordinator.pendingURLs = nil
                }
            }
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !prefsStore.onboardingCompletedV1 },
            set: { _ in }
        )
    }

    private var shareSheetBinding: Binding<Bool> {
        Binding(
            get: { coordinator.pendingURLs != nil },
            set: { presented in
                if !presented { coordinator.pendingURLs = nil }
            }
        )
    }
}
