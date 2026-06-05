import SwiftUI

/// Stages the share-extension UI walks through: in-progress while cleaning,
/// then `.ready` once the manifest has been written to the App Group inbox.
public enum CleaningPhase: Sendable {
    case cleaning
    case ready
}

/// Observable progress state driven by the cleaning pipeline.
@MainActor
public final class CleaningProgressModel: ObservableObject {
    @Published public var fraction: Double
    @Published public var currentFile: String?
    @Published public var phase: CleaningPhase

    public init(
        fraction: Double = 0,
        currentFile: String? = nil,
        phase: CleaningPhase = .cleaning
    ) {
        self.fraction = fraction
        self.currentFile = currentFile
        self.phase = phase
    }
}

/// Share-extension sheet — shows live cleaning progress, then a "Cleaned &
/// ready" success state with a primary CTA that re-opens (or asks the user
/// to open) the CleanShare host app so they can finish sharing.
///
/// We deliberately do NOT try to auto-launch the host app via private API
/// gymnastics: iOS 17+ has made that flow unreliable from share extensions
/// invoked through another app's share sheet. Instead, the user gets a clear
/// instruction and an explicit fresh-user-gesture "Open CleanShare" tap —
/// which gives `extensionContext.open` / responder-chain `openURL:` their
/// best shot at actually launching the app. If iOS still drops the launch,
/// the host app's foreground inbox sweep picks the manifest up on next open.
public struct CleaningProgressView: View {
    @ObservedObject var progress: CleaningProgressModel
    private let onCancel: (() -> Void)?
    private let onContinue: (() -> Void)?

    public init(
        progress: CleaningProgressModel,
        onCancel: (() -> Void)? = nil,
        onContinue: (() -> Void)? = nil
    ) {
        self.progress = progress
        self.onCancel = onCancel
        self.onContinue = onContinue
    }

    public var body: some View {
        switch self.progress.phase {
        case .cleaning:
            self.cleaningView
        case .ready:
            self.readyView
        }
    }

    private var cleaningView: some View {
        VStack(spacing: 16) {
            Text("Cleaning your media…")
                .font(.headline)
            ProgressView(value: self.progress.fraction)
            Text(self.progress.currentFile ?? "Preparing…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let onCancel = self.onCancel {
                Button("Cancel", role: .cancel, action: onCancel)
                    .padding(.top, 4)
            }
        }
        .padding()
    }

    private var readyView: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(BrandPalette.gradient)
                    .frame(width: 92, height: 92)
                    .shadow(color: BrandPalette.indigo.opacity(0.30), radius: 16, x: 0, y: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("Cleaned & ready")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text("Open CleanShare to continue sharing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let onContinue = self.onContinue {
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.app.fill")
                        Text("Open CleanShare")
                    }
                }
                .buttonStyle(CleanSharePrimaryButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }
}
