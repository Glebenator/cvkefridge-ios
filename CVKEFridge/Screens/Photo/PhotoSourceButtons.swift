import PhotosUI
import SwiftUI

/// The controls that give a food a photo: "Take a photo" and "Choose a photo" for a food with no photo, and
/// "Change photo" (with the same two sources) and "Remove photo" for a food with a photo. The screen of a food and the
/// add form use it.
///
/// PLACEHOLDER: this file has only "Choose a photo", with the photo picker of the system, and "Remove photo". The
/// Photos agent replaces the body. The signature `PhotoSourceButtons(hasPhoto:isBusy:onPicture:onRemove:)` stays.
///
/// ```swift
/// // The screen of a food
/// PhotoSourceButtons(
///     hasPhoto: model.photos[id] != nil,
///     isBusy: model.photoImports.contains(id),
///     onPicture: { model.setPhoto(productId: id, picture: $0) },
///     onRemove: { model.removePhoto(productId: id) }
/// )
/// // The add form
/// PhotoSourceButtons(
///     hasPhoto: model.formPhoto(token) != nil,
///     isBusy: model.formPhotos[token] == .making,
///     onPicture: { model.makeFormPhoto(token: token, picture: $0) },
///     onRemove: { model.discardFormPhoto(token: token) }
/// )
/// ```
///
/// Contract:
/// - The photo picker of the system needs no permission. It gives the app only the picture that the person selects.
/// - "Take a photo" is there when `model.camera.access()` is not `.noCamera`. Explain the camera before
///   `model.camera.requestAccess()`. When the access is `.blocked`, say so and offer the Settings app. The person
///   can always choose a photo.
/// - Give the picture to `onPicture` as a `PictureSource`: the bytes of the picture, or a file. The model makes the
///   photo off the main actor, and it gives the message when the picture cannot be read.
/// - While `isBusy` is true, the controls are off and the words "Adding the photo…" show.
struct PhotoSourceButtons: View {
    private let hasPhoto: Bool
    private let isBusy: Bool
    private let onPicture: (PictureSource) -> Void
    private let onRemove: (() -> Void)?

    @State private var picked: PhotosPickerItem?

    /// - Parameters:
    ///   - hasPhoto: True when the food has a photo now.
    ///   - isBusy: True while the app makes the photo from a picture.
    ///   - onPicture: The person selected or took a picture.
    ///   - onRemove: The person selected "Remove photo", or nil for no such control.
    init(
        hasPhoto: Bool,
        isBusy: Bool = false,
        onPicture: @escaping (PictureSource) -> Void,
        onRemove: (() -> Void)? = nil
    ) {
        self.hasPhoto = hasPhoto
        self.isBusy = isBusy
        self.onPicture = onPicture
        self.onRemove = onRemove
    }

    var body: some View {
        if isBusy {
            LoadingView("Adding the photo…", style: .plain)
        } else {
            PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) {
                Label(hasPhoto ? "Change photo" : "Choose a photo", icon: hasPhoto ? .photoChange : .photoAdd)
            }
            .accessibilityIdentifier(hasPhoto ? "photo_change" : "photo_choose")
            .onChange(of: picked) { _, item in
                guard let item else {
                    return
                }
                picked = nil
                Task {
                    // A picture that cannot be read gives empty bytes. The model then says that the photo failed.
                    let data = try? await item.loadTransferable(type: Data.self)
                    onPicture(.data(data ?? Data()))
                }
            }
            if hasPhoto, let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove photo", icon: .photoRemove)
                }
                .accessibilityIdentifier("photo_remove")
            }
        }
    }
}
