import SwiftUI

/// Observable progress state driven by the cleaning pipeline.
@MainActor
public final class CleaningProgressModel: ObservableObject {
    @Published public var fraction: Double
    @Published public var currentFile: String?

    public init(fraction: Double = 0, currentFile: String? = nil) {
        self.fraction = fraction
        self.currentFile = currentFile
    }
}

/// Minimal progress sheet shown while media is being cleaned.
public struct CleaningProgressView: View {
    @ObservedObject var progress: CleaningProgressModel

    public init(progress: CleaningProgressModel) {
        self.progress = progress
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Cleaning your media…")
                .font(.headline)
            ProgressView(value: progress.fraction)
            Text(progress.currentFile ?? "Preparing…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
