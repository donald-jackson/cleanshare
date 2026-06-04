import SwiftUI
import UIKit

/// Wraps `UIActivityViewController` for SwiftUI so the host app can re-present the
/// system share sheet with the extension's cleaned output files. See PLAN.md §6.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
