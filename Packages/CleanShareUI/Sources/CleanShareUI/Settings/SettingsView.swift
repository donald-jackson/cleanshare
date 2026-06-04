import CleanShareCore
import SwiftUI

/// User-facing settings for what metadata to keep, how to handle Live Photos,
/// and on-device diagnostics. Backed by `CleaningPreferencesStore`, which
/// persists to the shared App Group suite. See PLAN.md §4.5, §4.6, §9.
public struct SettingsView: View {
    @ObservedObject private var prefsStore: CleaningPreferencesStore
    @State private var showGPSConfirmation = false
    @State private var diagnosticsEnabled = false

    public init(prefsStore: CleaningPreferencesStore) {
        self.prefsStore = prefsStore
    }

    public var body: some View {
        Form {
            metadataSection
            locationSection
            livePhotosSection
            diagnosticsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .alert("Keep GPS in shared photos?", isPresented: $showGPSConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable") { prefsStore.keepGPS = true }
        } message: {
            Text("Photos with GPS coordinates reveal where they were taken. Are you sure?")
        }
    }

    private var metadataSection: some View {
        Section("Metadata to keep") {
            Toggle("Keep orientation", isOn: $prefsStore.keepOrientation)
            Toggle("Keep ICC color profile", isOn: $prefsStore.keepICCProfile)
            Toggle("Keep capture date", isOn: $prefsStore.keepCaptureDate)
            Toggle("Keep camera make & model", isOn: $prefsStore.keepCameraMakeModel)
        }
    }

    private var locationSection: some View {
        Section("Location (GPS)") {
            Toggle("Keep location (GPS)", isOn: Binding(
                get: { prefsStore.keepGPS },
                set: { newValue in
                    if newValue {
                        showGPSConfirmation = true
                    } else {
                        prefsStore.keepGPS = false
                    }
                }
            ))
        }
    }

    private var livePhotosSection: some View {
        Section("Live Photos") {
            Picker("When sharing Live Photos", selection: $prefsStore.livePhotoMode) {
                ForEach(LivePhotoMode.allCases, id: \.self) { mode in
                    Text(label(for: mode)).tag(mode)
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        Section {
            Toggle("Help improve CleanShare", isOn: Binding(
                get: { diagnosticsEnabled },
                set: { newValue in
                    diagnosticsEnabled = newValue
                    #if canImport(MetricKit)
                    if newValue {
                        MetricKitCollector.subscribe()
                    } else {
                        MetricKitCollector.unsubscribe()
                    }
                    #endif
                }
            ))
            NavigationLink("View & export reports", destination: DiagnosticsView())
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("When enabled, MetricKit crash reports are stored on-device only. Open the reports screen to export. No automatic upload.")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink("About CleanShare", destination: AboutView())
        }
    }

    private func label(for mode: LivePhotoMode) -> String {
        switch mode {
        case .prompt: return "Ask every time"
        case .downgradeToStill: return "Share as still photo"
        case .preservePairing: return "Keep Live Photo"
        case .repairWithFreshID: return "Keep Live Photo (fresh ID)"
        }
    }
}
