import CVKEFridgeFeatures
import SwiftUI

/// The photo of the add form, as the last section of the form: "Take a photo" and "Choose a photo", or the photo
/// with "Change photo" and "Remove photo". It takes the place of `FormPhotoField` in `ui/AddFoodScreen.kt` of the
/// Android app.
///
/// The app makes the photo at once (`FridgeModel.makeFormPhoto`), and the product gets it after the save. While the
/// app makes the photo, the section says so and the form cannot save: the section says that also. In the Android app
/// "Save" does nothing then, with no reason.
struct AddFoodPhotoSection: View {
    /// The token of the form.
    let token: String

    @Environment(FridgeModel.self) private var model

    var body: some View {
        let photo = model.formPhotos[token]
        Section {
            if case .ready(_, let url) = photo {
                FormPhotoPreview(url: url)
            }
            PhotoSourceButtons(
                hasPhoto: model.formPhoto(token) != nil,
                isBusy: photo == .making,
                onPicture: { model.makeFormPhoto(token: token, picture: $0) },
                onRemove: { model.discardFormPhoto(token: token) }
            )
        } header: {
            Text("Photo")
        } footer: {
            if photo == .making {
                Text("You can save when the photo is ready.")
                    .accessibilityIdentifier("form_photo_making")
            }
        }
    }
}

/// The photo of the form, before the product has it. The picture is decoded off the main actor, at the size of its
/// box.
private struct FormPhotoPreview: View {
    /// The file of the prepared photo, or nil when the file is not there.
    let url: URL?

    @Environment(FridgeModel.self) private var model
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @State private var image: UIImage?

    var body: some View {
        // 96 points, as in the Android app, and not more than 1.5 times that with large text.
        let side = 96 * min(scale, 1.5)
        ZStack {
            Palette.surfaceContainerHigh
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(icon: .photoAdd)
                    .font(.title2)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
        }
        .frame(width: side, height: side)
        .clipShape(Radius.shape(Radius.medium))
        .padding(.vertical, Space.s1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Photo of the food"))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("form_photo_image")
        .task(id: url) {
            image = nil
            if let url {
                let pixels = Int((96 * 1.5 * displayScale).rounded(.up))
                image = await model.image(of: ProductPhoto(url: url), pixelSize: pixels)
            }
        }
    }
}
