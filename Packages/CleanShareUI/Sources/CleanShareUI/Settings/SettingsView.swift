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
            self.metadataSection
            self.locationSection
            self.livePhotosSection
            self.diagnosticsSection
            self.aboutSection
        }
        .navigationTitle("Settings")
        .alert("Keep GPS in shared photos?", isPresented: self.$showGPSConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable") { self.prefsStore.keepGPS = true }
        } message: {
            Text("Photos with GPS coordinates reveal where they were taken. Are you sure?")
        }
    }

    private var metadataSection: some View {
        Section("Metadata to keep") {
            Toggle("Keep orientation", isOn: self.$prefsStore.keepOrientation)
            Toggle("Keep ICC color profile", isOn: self.$prefsStore.keepICCProfile)
            Toggle("Keep capture date", isOn: self.$prefsStore.keepCaptureDate)
            Toggle("Keep camera make & model", isOn: self.$prefsStore.keepCameraMakeModel)
        }
    }

    private var locationSection: some View {
        Section("Location (GPS)") {
            Toggle("Keep location (GPS)", isOn: Binding(
                get: { self.prefsStore.keepGPS },
                set: { newValue in
                    if newValue {
                        self.showGPSConfirmation = true
                    } else {
                        self.prefsStore.keepGPS = false
                    }
                }
            ))
        }
    }

    private var livePhotosSection: some View {
        Section("Live Photos") {
            Picker("When sharing Live Photos", selection: self.$prefsStore.livePhotoMode) {
                ForEach(LivePhotoMode.allCases, id: \.self) { mode in
                    Text(self.label(for: mode)).tag(mode)
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        Section {
            Toggle("Help improve CleanShare", isOn: Binding(
                get: { self.diagnosticsEnabled },
                set: { newValue in
                    self.diagnosticsEnabled = newValue
                    // MetricKit payload APIs are iOS-only even where the module
                    // imports (macOS); gate on the platform. See MetricKitCollector.
                    #if os(iOS)
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
            Text(
                "When enabled, MetricKit crash reports are stored on-device only. "
                    + "Open the reports screen to export. No automatic upload."
            )
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink("About CleanShare", destination: AboutView())
        }
    }

    private func label(for mode: LivePhotoMode) -> String {
        switch mode {
        case .prompt: "Ask every time"
        case .downgradeToStill: "Share as still photo"
        case .preservePairing: "Keep Live Photo"
        case .repairWithFreshID: "Keep Live Photo (fresh ID)"
        }
    }
}
