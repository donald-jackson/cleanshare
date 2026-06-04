import SwiftUI
import UIKit

/// Wraps `UIActivityViewController` for SwiftUI so the host app can re-present the
/// system share sheet with the extension's cleaned output files. See PLAN.md §6.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in self.onComplete() }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
