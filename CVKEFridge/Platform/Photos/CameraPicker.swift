import CVKEFridgeFeatures
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The camera of the system, to take one picture for the photo of a food. Show it in a full-screen cover, only when
/// `CameraPicker.isAvailable` is true and the camera access is `.allowed`.
///
/// The picture stays in memory. The camera does not put it into the photo library, and the app writes no file of it:
/// `CameraPicture.data(of:)` makes the bytes for `PictureSource.data` from it.
struct CameraPicker: UIViewControllerRepresentable {
    /// The person took a picture and selected "Use Photo".
    let onPicture: (UIImage) -> Void
    /// The person closed the camera with no picture.
    let onCancel: () -> Void

    /// True when the device has a camera that the system camera can use. The Simulator has none. The value does not
    /// change while the app runs, so the app reads it one time.
    @MainActor static let isAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPicture(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

/// The bytes of a picture of the camera, for `PictureSource.data`.
enum CameraPicture {
    /// Draws the picture upright, at the size of a photo (`PhotoFiles.targetSize`), and gives it as PNG bytes, off the
    /// main actor. PNG has no loss, so the JPEG of the photo is made only one time. The bytes have no metadata. Nil
    /// when the picture has no size.
    @concurrent
    static func data(of image: UIImage) async -> Data? {
        // `size` is in points and with the orientation applied.
        let width = Int((image.size.width * image.scale).rounded())
        let height = Int((image.size.height * image.scale).rounded())
        guard width > 0, height > 0 else {
            return nil
        }
        let target = PhotoFiles.targetSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: target.width, height: target.height), format: format)
        return renderer.pngData { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: target.width, height: target.height))
        }
    }
}
