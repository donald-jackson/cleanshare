import SwiftUI

/// App information screen: version, privacy posture, supported formats, and
/// open-source / legal links. The "Zero data collected", "Supported formats",
/// and "Open source" sections double as App Store screenshot sources.
/// See PLAN.md §9, §13.5, §14.
public struct AboutView: View {
    public init() {}

    /// Teal → indigo brand gradient (PLAN.md §14.2).
    private static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.098, green: 0.706, blue: 0.690),
            Color(red: 0.231, green: 0.247, blue: 0.722)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var sourceURL: URL {
        let string = Bundle.main.object(forInfoDictionaryKey: "CleanShareSourceURL") as? String
            ?? "https://github.com/<placeholder>/cleanshare"
        return URL(string: string) ?? URL(string: "https://github.com/<placeholder>/cleanshare")!
    }

    public var body: some View {
        List {
            self.headerSection
            self.privacySection
            self.formatsSection
            self.openSourceSection
            self.legalSection
        }
        .navigationTitle("About")
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 8) {
                Text("CleanShare")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Version \(self.version) (\(self.build))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .listRowInsets(EdgeInsets())
            .background(Self.brandGradient)
        }
    }

    private var privacySection: some View {
        Section {
            self.privacyRow(
                systemImage: "person.slash.fill",
                title: "No accounts",
                caption: "There's no sign-up, no login, no identity."
            )
            self.privacyRow(
                systemImage: "chart.bar.xaxis.ascending",
                title: "No analytics",
                caption: "We don't track what you do or what you share."
            )
            self.privacyRow(
                systemImage: "wifi.slash",
                title: "No network",
                caption: "Everything happens on your device, offline."
            )
        } header: {
            Text("Zero data collected")
        } footer: {
            Text("CleanShare never connects to the internet. We test for it on every commit via CI.")
        }
    }

    private func privacyRow(systemImage: String, title: String, caption: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color(red: 0.098, green: 0.706, blue: 0.690))
        }
    }

    private var formatsSection: some View {
        Section("Supported formats") {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Photos")
                        .font(.body)
                    Text("JPEG, HEIC/HEIF, PNG, GIF, TIFF, WebP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "photo")
                    .foregroundStyle(Color(red: 0.098, green: 0.706, blue: 0.690))
            }
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Videos")
                        .font(.body)
                    Text("MP4, MOV (H.264, HEVC, ProRes)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "video")
                    .foregroundStyle(Color(red: 0.231, green: 0.247, blue: 0.722))
            }
        }
    }

    private var openSourceSection: some View {
        Section("Open source (MIT)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("CleanShare")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.231, green: 0.247, blue: 0.722))
                Text("Powered entirely by Apple ImageIO and AVFoundation. Zero third-party SDKs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Link("View source on GitHub", destination: self.sourceURL)
            }
            .padding(.vertical, 4)
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            Link("Privacy", destination: URL(string: "https://cleanshare.dev/privacy")!)
            Link("Threat model", destination: URL(string: "https://cleanshare.dev/threat-model")!)
        }
    }
}
