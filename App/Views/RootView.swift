import CleanShareCore
import CleanShareUI
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var coordinator: ShareSheetCoordinator
    @StateObject private var prefsStore = CleaningPreferencesStore()
    @State private var showSettings = false
    @State private var showLivePhotoSheet = false
    @State private var livePhotoOnChoose: (LivePhotoMode) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("CleanShare")
                    .font(.largeTitle).bold()
                Text("Strip metadata before sharing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Try it on a Live Photo (sample)") {
                    livePhotoOnChoose = { mode in
                        showLivePhotoSheet = false
                        cleanSampleLivePhoto(mode: mode)
                    }
                    showLivePhotoSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView(prefsStore: prefsStore)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(prefsStore: prefsStore)
            }
        }
        .sheet(isPresented: $showLivePhotoSheet) {
            LivePhotoConsentSheet(prefsStore: prefsStore, onChoose: $livePhotoOnChoose)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: shareSheetBinding) {
            if let urls = coordinator.pendingURLs {
                ActivityView(activityItems: urls) {
                    coordinator.pendingURLs = nil
                }
            }
        }
    }

    /// Cleans the bundled sample Live Photo pair with the user's chosen mode and
    /// presents the system share sheet on the cleaned output.
    private func cleanSampleLivePhoto(mode: LivePhotoMode) {
        guard
            let still = Bundle.main.url(forResource: "Sample-DirtyLivePhoto", withExtension: "heic"),
            let video = Bundle.main.url(forResource: "Sample-DirtyLivePhoto", withExtension: "mov")
        else { return }

        let prefs = prefsStore.current
        Task {
            do {
                let workspace = try Workspace(appGroupID: CleaningPreferencesStore.suiteName)
                let job = try await workspace.newJob()
                let stillIn = job.inDir.appendingPathComponent(still.lastPathComponent)
                let videoIn = job.inDir.appendingPathComponent(video.lastPathComponent)
                try FileManager.default.copyItem(at: still, to: stillIn)
                try FileManager.default.copyItem(at: video, to: videoIn)

                let result = try await LivePhotoCleaner().clean(
                    still: stillIn, video: videoIn, outDir: job.outDir, mode: mode, prefs: prefs
                )
                var urls = [result.still.outputURL]
                if let video = result.video { urls.append(video.outputURL) }
                coordinator.pendingURLs = urls
            } catch {
                // The sample demo is best-effort; failures leave the UI idle.
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
