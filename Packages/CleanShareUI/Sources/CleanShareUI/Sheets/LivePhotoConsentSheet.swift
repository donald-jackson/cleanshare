import CleanShareCore
import SwiftUI

/// First-encounter consent sheet for Live Photos. Presents the three concrete
/// handling modes with a one-line explanation each, plus a "Don't ask again"
/// toggle that persists the choice to `livePhotoDefaultMode`. See PLAN.md §4.5.
public struct LivePhotoConsentSheet: View {
    @ObservedObject private var prefsStore: CleaningPreferencesStore
    @Binding private var onChoose: (LivePhotoMode) -> Void
    @State private var dontAskAgain = false

    public init(
        prefsStore: CleaningPreferencesStore,
        onChoose: Binding<(LivePhotoMode) -> Void>
    ) {
        self.prefsStore = prefsStore
        self._onChoose = onChoose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Live Photo detected")
                .font(.title2.bold())

            VStack(spacing: 12) {
                modeButton(
                    .downgradeToStill,
                    title: "Share as still photo",
                    detail: "Drops the paired video for the strongest privacy."
                )
                modeButton(
                    .preservePairing,
                    title: "Keep Live Photo",
                    detail: "Cleans both, but keeps the original pairing token."
                )
                modeButton(
                    .repairWithFreshID,
                    title: "Keep Live Photo (fresh ID)",
                    detail: "Cleans both and re-pairs with a new, uncorrelatable ID."
                )
            }

            Toggle("Don't ask again", isOn: $dontAskAgain)
        }
        .padding()
    }

    private func modeButton(
        _ mode: LivePhotoMode,
        title: String,
        detail: String
    ) -> some View {
        Button {
            choose(mode)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func choose(_ mode: LivePhotoMode) {
        if dontAskAgain {
            prefsStore.livePhotoDefaultMode = mode
        }
        onChoose(mode)
    }
}
