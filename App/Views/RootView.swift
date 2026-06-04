import CleanShareCore
import CleanShareUI
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var coordinator: ShareSheetCoordinator
    @StateObject private var prefsStore = CleaningPreferencesStore()
    @State private var showSettings = false
    @State private var showLivePhotoSheet = false
    @State private var livePhotoOnChoose: (LivePhotoMode) -> Void = { _ in }
    @State private var sampleDiff: SampleDiffPair?
    @State private var showPhotoPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(String(localized: "CleanShare"))
                    .font(.largeTitle).bold()
                Text(String(localized: "Strip metadata before sharing"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(String(localized: "Try it on a sample photo")) {
                    cleanSamplePhoto()
                }
                .buttonStyle(.borderedProminent)

                Button(String(localized: "Clean photos…")) {
                    showPhotoPicker = true
                }
                .buttonStyle(.borderedProminent)

                Button(String(localized: "Try it on a Live Photo (sample)")) {
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
                    .accessibilityLabel(String(localized: "Settings"))
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
        .sheet(item: $sampleDiff) { pair in
            SampleDiffView(beforeURL: pair.beforeURL, afterURL: pair.afterURL)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { results in
                showPhotoPicker = false
                cleanPicked(results)
            }
            .ignoresSafeArea()
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

    /// Cleans the bundled sample photo and presents a BEFORE / AFTER metadata diff.
    private func cleanSamplePhoto() {
        guard let sample = Bundle.main.url(forResource: "Sample-DirtyPhoto", withExtension: "jpg") else {
            return
        }

        let prefs = prefsStore.current
        Task {
            do {
                let workspace = try Workspace(appGroupID: CleaningPreferencesStore.suiteName)
                let job = try await workspace.newJob()
                let input = job.inDir.appendingPathComponent(sample.lastPathComponent)
                try FileManager.default.copyItem(at: sample, to: input)
                let output = job.outDir.appendingPathComponent(sample.lastPathComponent)

                let receipt = try await ImageIOCleaner().clean(input: input, output: output, prefs: prefs)
                sampleDiff = SampleDiffPair(beforeURL: input, afterURL: receipt.outputURL)
            } catch {
                // The sample demo is best-effort; failures leave the UI idle.
            }
        }
    }

    /// Cleans the photos/videos the user picked from their library and presents the
    /// system share sheet on the cleaned output. Inputs are hardlinked into a fresh
    /// Workspace job (no transcode), then run through `CleaningPipeline`. See PLAN.md §3.2.
    private func cleanPicked(_ results: [PHPickerResult]) {
        let providers = results.map(\.itemProvider)
        guard !providers.isEmpty else { return }

        let prefs = prefsStore.current
        Task {
            do {
                let workspace = try Workspace(appGroupID: CleaningPreferencesStore.suiteName)
                let job = try await workspace.newJob()

                var items: [CleaningPipeline.InputItem] = []
                for provider in providers {
                    if let item = await importItem(provider, into: job.inDir) {
                        items.append(item)
                    }
                }
                guard !items.isEmpty else { return }

                let pipeline = CleaningPipeline(workspace: workspace, prefs: prefs)
                await pipeline.enqueue(items)

                var cleaned: [URL] = []
                for try await event in await pipeline.run() {
                    if case let .completed(_, receipt) = event {
                        cleaned.append(receipt.outputURL)
                    }
                }
                guard !cleaned.isEmpty else { return }
                coordinator.pendingURLs = cleaned
            } catch {
                // Best-effort: failures leave the UI idle.
            }
        }
    }

    /// Loads a picked item's file representation and hardlinks (or copies, across
    /// volumes) it into `inDir`, returning a `CleaningPipeline` input item. Returns
    /// `nil` for unsupported types or load failures.
    private func importItem(_ provider: NSItemProvider, into inDir: URL) async -> CleaningPipeline.InputItem? {
        guard let (typeID, kind) = Self.supportedType(for: provider) else { return nil }
        let id = UUID()
        let dest: URL? = await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeID) { srcURL, _ in
                guard let srcURL else {
                    continuation.resume(returning: nil)
                    return
                }
                let ext = srcURL.pathExtension.isEmpty ? "dat" : srcURL.pathExtension
                let target = inDir.appendingPathComponent("\(id.uuidString).\(ext)")
                let fm = FileManager.default
                if (try? fm.linkItem(at: srcURL, to: target)) != nil {
                    continuation.resume(returning: target)
                } else if (try? fm.copyItem(at: srcURL, to: target)) != nil {
                    continuation.resume(returning: target)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        guard let dest else { return nil }
        return (id: id, sourceURL: dest, kind: kind)
    }

    /// Picks the first registered type identifier that maps to a supported
    /// `MediaKind`, skipping `.livePhoto` (the pipeline cleans the still/video
    /// components, not the bundled live-photo type).
    private static func supportedType(for provider: NSItemProvider) -> (String, MediaKind)? {
        for identifier in provider.registeredTypeIdentifiers {
            guard
                let type = UTType(identifier),
                let kind = MediaKind(uti: type),
                kind != .livePhoto
            else { continue }
            return (identifier, kind)
        }
        return nil
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

/// Identifiable pairing of the original and cleaned sample-photo URLs, used to
/// drive the `SampleDiffView` sheet.
private struct SampleDiffPair: Identifiable {
    let id = UUID()
    let beforeURL: URL
    let afterURL: URL
}
