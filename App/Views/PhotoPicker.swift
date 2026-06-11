import PhotosUI
import SwiftUI

/// Wraps `PHPickerViewController` for SwiftUI. Configured for multi-select across
/// images, videos, and Live Photos, and pinned to `.current` representation mode
/// so HEIC is never silently transcoded to JPEG. See PLAN.md §3.2.
struct PhotoPicker: UIViewControllerRepresentable {
    /// 0 = unlimited; defaults to multi-select for the main "Clean photos…"
    /// flow. The inspector flow passes 1 to constrain to a single file.
    var selectionLimit: Int = 0
    let onPicked: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = self.selectionLimit
        config.preferredAssetRepresentationMode = .current
        config.filter = .any(of: [.images, .videos, .livePhotos])
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: PHPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: self.onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPicked: ([PHPickerResult]) -> Void

        init(onPicked: @escaping ([PHPickerResult]) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            self.onPicked(results)
        }
    }
}
