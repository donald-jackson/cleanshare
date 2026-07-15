import SwiftUI

/// Stages the share-extension UI walks through: in-progress while cleaning,
/// `.ready` once the manifest has been written to the App Group inbox, or
/// `.failed` if nothing could be cleaned (fail closed — never a false "ready").
public enum CleaningPhase: Sendable {
    case cleaning
    case ready
    case failed
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

/// Share-extension sheet — shows live cleaning progress, then a brief
/// "Cleaned & ready" success state before the extension dismisses itself
/// and posts a local notification the user taps to continue sharing inside
/// the CleanShare host app.
///
/// We deliberately do NOT try to auto-launch the host app from the extension:
/// iOS 17+ has made every "extension switches to host" path
/// (`extensionContext.open`, responder-chain `openURL:`, Universal Links from
/// a foreground extension) unreliable when the extension was invoked through
/// another app's share sheet. The notification is the user-driven gesture
/// that iOS does honour, and the host app's foreground inbox sweep is the
/// belt-and-braces backup if the user denied notifications.
public struct CleaningProgressView: View {
    @ObservedObject var progress: CleaningProgressModel
    private let onCancel: (() -> Void)?

    public init(
        progress: CleaningProgressModel,
        onCancel: (() -> Void)? = nil
    ) {
        self.progress = progress
        self.onCancel = onCancel
    }

    public var body: some View {
        switch self.progress.phase {
        case .cleaning:
            self.cleaningView
        case .ready:
            self.readyView
        case .failed:
            self.failedView
        }
    }

    private var failedView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 84, height: 84)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            VStack(spacing: 4) {
                Text("Couldn't clean")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Nothing was shared. Your original file was left untouched.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
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
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(BrandPalette.gradient)
                    .frame(width: 84, height: 84)
                    .shadow(color: BrandPalette.indigo.opacity(0.30), radius: 14, x: 0, y: 6)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("Cleaned")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tap the CleanShare notification to keep sharing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}
