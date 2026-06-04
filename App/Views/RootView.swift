import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("CleanShare")
                .font(.largeTitle).bold()
            Text("Strip metadata before sharing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
