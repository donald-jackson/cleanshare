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
    @State private var showInspectPicker = false
    @State private var inspectTarget: InspectTarget?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 32)

                VStack(spacing: 10) {
                    Text(String(localized: "CleanShare"))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(BrandPalette.ink)
                    Text(String(localized: "Strip metadata before sharing"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 28)

                VStack(spacing: 14) {
                    Button {
                        self.showPhotoPicker = true
                    } label: {
                        Label(String(localized: "Clean photos…"), systemImage: "wand.and.stars")
                    }
                    .buttonStyle(CleanSharePrimaryButtonStyle())

                    Button {
                        self.showInspectPicker = true
                    } label: {
                        Label(String(localized: "Inspect a photo"), systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(CleanShareSecondaryButtonStyle())

                    Button {
                        self.cleanSamplePhoto()
                    } label: {
                        Label(String(localized: "Try on a sample photo"), systemImage: "photo")
                    }
                    .buttonStyle(CleanShareSecondaryButtonStyle())

                    Button {
                        self.livePhotoOnChoose = { mode in
                            self.showLivePhotoSheet = false
                            self.cleanSampleLivePhoto(mode: mode)
                        }
                        self.showLivePhotoSheet = true
                    } label: {
                        Label(String(localized: "Try on a sample Live Photo"), systemImage: "livephoto")
                    }
                    .buttonStyle(CleanShareSecondaryButtonStyle())
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(String(localized: "Settings"))
                }
            }
        }
        .fullScreenCover(isPresented: self.onboardingBinding) {
            OnboardingView(prefsStore: self.prefsStore)
        }
        .sheet(isPresented: self.$showSettings) {
            NavigationStack {
                SettingsView(prefsStore: self.prefsStore)
            }
        }
        .sheet(item: self.$sampleDiff) { pair in
            SampleDiffView(beforeURL: pair.beforeURL, afterURL: pair.afterURL)
        }
        .sheet(isPresented: self.$showPhotoPicker) {
            PhotoPicker { results in
                self.showPhotoPicker = false
                self.cleanPicked(results)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: self.$showInspectPicker) {
            PhotoPicker(selectionLimit: 1) { results in
                self.showInspectPicker = false
                self.importForInspection(results.first?.itemProvider)
            }
            .ignoresSafeArea()
        }
        .sheet(item: self.$inspectTarget) { target in
            MetadataInspectionView(
                url: target.url,
                kind: target.kind,
                onCleanAndShare: {
                    self.cleanSingleFile(url: target.url, kind: target.kind)
                }
            )
        }
        .sheet(isPresented: self.$showLivePhotoSheet) {
            LivePhotoConsentSheet(prefsStore: self.prefsStore, onChoose: self.$livePhotoOnChoose)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: self.shareSheetBinding) {
            if let urls = coordinator.pendingURLs {
                ActivityView(activityItems: urls) {
                    self.coordinator.pendingURLs = nil
                }
            }
        }
    }

    /// Cleans the bundled sample photo and presents a BEFORE / AFTER metadata diff.
    private func cleanSamplePhoto() {
        guard let sample = Bundle.main.url(forResource: "Sample-DirtyPhoto", withExtension: "jpg") else {
            return
        }

        let prefs = self.prefsStore.current
        Task {
            do {
                let workspace = try Workspace(appGroupID: CleaningPreferencesStore.suiteName)
                let job = try await workspace.newJob()
                let input = job.inDir.appendingPathComponent(sample.lastPathComponent)
                try FileManager.default.copyItem(at: sample, to: input)
                let output = job.outDir.appendingPathComponent(sample.lastPathComponent)

                let receipt = try await ImageIOCleaner().clean(input: input, output: output, prefs: prefs)
                self.sampleDiff = SampleDiffPair(beforeURL: input, afterURL: receipt.outputURL)
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

        let prefs = self.prefsStore.current
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
                    if case .completed(_, let receipt) = event {
                        cleaned.append(receipt.outputURL)
                    }
                }
                guard !cleaned.isEmpty else { return }
                self.coordinator.pendingURLs = cleaned
            } catch {
                // Best-effort: failures leave the UI idle.
            }
        }
    }

    /// Imports a single picked item into a fresh workspace job and presents the
    /// `MetadataInspectionView`. The file stays in the App Group container so
    /// the inspector can read it; the regular workspace TTL sweep cleans it up
    /// later.
    private func importForInspection(_ provider: NSItemProvider?) {
        guard let provider else { return }
        Task {
            do {
                let workspace = try Workspace(appGroupID: CleaningPreferencesStore.suiteName)
                let job = try await workspace.newJob()
                guard let item = await importItem(provider, into: job.inDir) else { return }
                self.inspectTarget = InspectTarget(url: item.sourceURL, kind: item.kind)
            } catch {
                // Best-effort: failures leave the UI idle.
            }
        }
    }

    /// Cleans a single file already in the workspace and queues it for the
    /// share sheet. Used by the inspector's "Clean and share" CTA so the user
    /// goes from "here's what's hiding" to "here's the cleaned version" in one
    /// tap, without re-picking.
    private func cleanSingleFile(url: URL, kind: MediaKind) {
        let prefs = self.prefsStore.current
        Task {
            do {
                let workspace = try Workspace(appGroupID: CleaningPreferencesStore.suiteName)
                let job = try await workspace.newJob()
                let input = job.inDir.appendingPathComponent(url.lastPathComponent)
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: input)
                do {
                    try fileManager.linkItem(at: url, to: input)
                } catch {
                    try fileManager.copyItem(at: url, to: input)
                }
                let pipeline = CleaningPipeline(workspace: workspace, prefs: prefs)
                await pipeline.enqueue([(id: UUID(), sourceURL: input, kind: kind)])

                var cleaned: [URL] = []
                for try await event in await pipeline.run() {
                    if case .completed(_, let receipt) = event {
                        cleaned.append(receipt.outputURL)
                    }
                }
                guard !cleaned.isEmpty else { return }
                self.coordinator.pendingURLs = cleaned
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
                let fileManager = FileManager.default
                if (try? fileManager.linkItem(at: srcURL, to: target)) != nil {
                    continuation.resume(returning: target)
                } else if (try? fileManager.copyItem(at: srcURL, to: target)) != nil {
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

        let prefs = self.prefsStore.current
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
                self.coordinator.pendingURLs = urls
            } catch {
                // The sample demo is best-effort; failures leave the UI idle.
            }
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !self.prefsStore.onboardingCompletedV1 },
            set: { _ in }
        )
    }

    private var shareSheetBinding: Binding<Bool> {
        Binding(
            get: { self.coordinator.pendingURLs != nil },
            set: { presented in
                if !presented { self.coordinator.pendingURLs = nil }
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

/// File the user picked for inspection. Drives the `MetadataInspectionView`
/// sheet via `.sheet(item:)`.
private struct InspectTarget: Identifiable {
    let id = UUID()
    let url: URL
    let kind: MediaKind
}
