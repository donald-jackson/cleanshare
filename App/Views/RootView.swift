import SwiftUI

struct RootView: View {
    @EnvironmentObject private var coordinator: ShareSheetCoordinator

    var body: some View {
        VStack(spacing: 16) {
            Text("CleanShare")
                .font(.largeTitle).bold()
            Text("Strip metadata before sharing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .sheet(isPresented: shareSheetBinding) {
            if let urls = coordinator.pendingURLs {
                ActivityView(activityItems: urls) {
                    coordinator.pendingURLs = nil
                }
            }
        }
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
