import CVKEFridgeFeatures
import PhotosUI
import SwiftUI

/// The controls that give a food a photo: "Take a photo" and "Choose a photo" for a food with no photo, and
/// "Change photo" (a menu with the same two sources) and "Remove photo" for a food with a photo. The screen of a food
/// and the add form use it. The buttons are in one row, or one below the other when the row is too narrow, for
/// example with large text.
///
/// ```swift
/// // The screen of a food
/// PhotoSourceButtons(
///     hasPhoto: model.photos[id] != nil,
///     isBusy: model.photoImports.contains(id),
///     onPicture: { model.setPhoto(productId: id, picture: $0) },
///     onRemove: { model.removePhoto(productId: id) }
/// )
/// // The add form: the model knows about the load of the picture at once, so "Save" is off during the load
/// PhotoSourceButtons(
///     hasPhoto: model.formPhoto(token) != nil,
///     isBusy: model.formPhotos[token] == .making,
///     onPictureStart: {
///         let load = model.startFormPhoto(token: token)
///         return { model.makeFormPhoto(token: token, load: load, picture: $0) }
///     },
///     onRemove: { model.discardFormPhoto(token: token) }
/// )
/// ```
///
/// - "Choose a photo" opens the photo picker of the system, with pictures only. It needs no permission: it gives the
///   app only the picture that the person selects. The bytes load off the main actor.
/// - "Take a photo" opens the camera of the system. It is there only when the device has a camera. Before iOS asks for
///   the camera, a dialog explains why. When the camera access is off, a dialog says so and opens the Settings app.
///   The person can always choose a photo. The picture of the camera stays in memory: it does not go into the photo
///   library or into a file.
/// - The picture goes to `onPicture` as `PictureSource.data`. The model makes the photo off the main actor, and it
///   gives the message when the picture cannot be read. A picture that does not load gives empty bytes, and so the
///   same message.
/// - While `isBusy` is true, or while the picture loads from the photo library, the words "Adding the photo…" show in
///   the place of the buttons.
/// - The buttons have no frame, so that each one is a separate target also in a row of a `List`. Each one is 44
///   points high or more.
struct PhotoSourceButtons: View {
    private let hasPhoto: Bool
    private let isBusy: Bool
    /// Called when the person selected or took a picture, before its bytes load. The result gets the picture.
    private let onPictureStart: () -> (PictureSource) -> Void
    private let onRemove: (() -> Void)?

    @Environment(FridgeModel.self) private var model
    @Environment(\.openURL) private var openURL

    /// The photo picker is open.
    @State private var choosing = false
    @State private var picked: PhotosPickerItem?
    /// The camera is open.
    @State private var taking = false
    @State private var dialog: CameraDialog?
    /// The selected picture loads from the photo library, or the picture of the camera is made smaller.
    @State private var loading = false

    /// A dialog about the camera access.
    private enum CameraDialog {
        /// Explains the camera before iOS asks.
        case explain
        /// The camera access is off.
        case blocked
    }

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
        self.init(hasPhoto: hasPhoto, isBusy: isBusy, onPictureStart: { onPicture }, onRemove: onRemove)
    }

    /// - Parameters:
    ///   - onPictureStart: The person selected or took a picture, and its bytes load now. The result gets the
    ///     picture when the bytes are there. The add form uses it, so that the model knows about the load at once.
    init(
        hasPhoto: Bool,
        isBusy: Bool = false,
        onPictureStart: @escaping () -> (PictureSource) -> Void,
        onRemove: (() -> Void)? = nil
    ) {
        self.hasPhoto = hasPhoto
        self.isBusy = isBusy
        self.onPictureStart = onPictureStart
        self.onRemove = onRemove
    }

    var body: some View {
        Group {
            if isBusy || loading {
                busy
                    .transition(.fade)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Space.s5) { buttons }
                    VStack(alignment: .leading, spacing: 0) { buttons }
                }
                .transition(.fade)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .motion(Motion.enter, value: isBusy || loading)
        .motion(Motion.selection, value: hasPhoto)
        .buttonStyle(.borderless)
        .labelStyle(PhotoButtonLabelStyle())
        .photosPicker(isPresented: $choosing, selection: $picked, matching: .images, preferredItemEncoding: .current)
        .onChange(of: picked) { _, item in
            guard let item else {
                return
            }
            picked = nil
            load(item)
        }
        .fullScreenCover(isPresented: $taking) {
            CameraPicker(
                onPicture: { image in
                    taking = false
                    use(image)
                },
                onCancel: { taking = false }
            )
            .ignoresSafeArea()
        }
        .alert("Take a photo with the camera", isPresented: shows(.explain)) {
            Button("Continue", action: askForCamera)
            Button("Not now", role: .cancel) {}
        } message: {
            Text(
                "To take a photo of the food, CVKE Fridge needs the camera. The photo stays on your device. The app does not send it. Next, iOS asks if CVKE Fridge can use the camera."
            )
        }
        .alert("Camera access is off", isPresented: shows(.blocked)) {
            Button("Open Settings", action: openSettings)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "iOS does not ask again. To take a photo, open Settings, select CVKE Fridge, and allow the camera. You can also choose a photo."
            )
        }
        // A first photo gives the success signal. A changed and a removed photo give the signal of their message.
        .haptic(trigger: hasPhoto) { old, new in !old && new ? .success : nil }
    }

    // MARK: The controls

    @ViewBuilder
    private var buttons: some View {
        if hasPhoto {
            changeButton
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove photo", icon: .photoRemove)
                }
                .accessibilityIdentifier("photo_remove")
            }
        } else {
            if canTake {
                Button(action: take) {
                    Label("Take a photo", icon: .camera)
                }
                .accessibilityIdentifier("photo_take")
            }
            Button(action: choose) {
                Label("Choose a photo", icon: .photoAdd)
            }
            .accessibilityIdentifier("photo_choose")
        }
    }

    /// "Change photo": a menu with the two sources, or the photo picker at once when the device has no camera.
    @ViewBuilder
    private var changeButton: some View {
        if canTake {
            Menu {
                Button(action: take) {
                    Label("Take a photo", icon: .camera)
                }
                .accessibilityIdentifier("photo_change_take")
                Button(action: choose) {
                    Label("Choose a photo", icon: .photoAdd)
                }
                .accessibilityIdentifier("photo_change_choose")
            } label: {
                Label("Change photo", icon: .photoChange)
            }
            .menuStyle(.button)
            .accessibilityIdentifier("photo_change")
        } else {
            Button(action: choose) {
                Label("Change photo", icon: .photoChange)
            }
            .accessibilityIdentifier("photo_change")
        }
    }

    private var busy: some View {
        HStack(spacing: Space.s3) {
            BrandSpinner(label: nil)
            Text("Adding the photo…")
                .font(Typography.body)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("photo_busy")
    }

    /// True while the `dialog` shows. The system sets it to false when the person closes the dialog.
    private func shows(_ dialog: CameraDialog) -> Binding<Bool> {
        Binding(
            get: { self.dialog == dialog },
            set: { shown in
                if !shown && self.dialog == dialog {
                    self.dialog = nil
                }
            }
        )
    }

    // MARK: The sources

    /// True when the device has a camera: the system camera can use it, and AVFoundation finds it. The Simulator can
    /// give the system camera with no camera device, so the two must agree. The value does not change while the app
    /// runs, so the app reads it one time.
    private static var cameraExists: Bool?

    /// True when "Take a photo" is there: the device has a camera. The access is read when the person selects "Take a
    /// photo".
    private var canTake: Bool {
        #if DEBUG
        if TestPictures.cameraAccess != nil {
            return true
        }
        #endif
        if let exists = Self.cameraExists {
            return exists
        }
        let exists = CameraPicker.isAvailable && model.camera.access() != .noCamera
        Self.cameraExists = exists
        return exists
    }

    private var cameraAccess: CameraAccess {
        #if DEBUG
        if let access = TestPictures.cameraAccess {
            return access
        }
        #endif
        return model.camera.access()
    }

    private func choose() {
        #if DEBUG
        if TestPictures.kind != nil {
            onPictureStart()(.data(TestPictures.next()))
            return
        }
        #endif
        choosing = true
    }

    private func take() {
        switch cameraAccess {
        case .allowed:
            openCamera()
        case .ask:
            dialog = .explain
        case .blocked:
            dialog = .blocked
        case .noCamera:
            break
        }
    }

    /// Asks iOS for the camera, after the explanation. When the person does not allow it, nothing more occurs: the
    /// next "Take a photo" says that the access is off.
    private func askForCamera() {
        #if DEBUG
        if TestPictures.cameraAccess != nil {
            if TestPictures.requestCameraAccess() == .allowed {
                openCamera()
            }
            return
        }
        #endif
        Task {
            if await model.camera.requestAccess() == .allowed {
                openCamera()
            }
        }
    }

    private func openCamera() {
        #if DEBUG
        if TestPictures.kind != nil {
            onPictureStart()(.data(TestPictures.next()))
            return
        }
        #endif
        taking = true
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    /// Loads the bytes of the selected picture, off the main actor. A picture that is in iCloud can take some time,
    /// so the words "Adding the photo…" show. The receiver of the picture is fixed before the load: a form that
    /// starts its next entry meanwhile does not get the picture.
    private func load(_ item: PhotosPickerItem) {
        let receive = onPictureStart()
        loading = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            loading = false
            receive(.data(data ?? Data()))
        }
    }

    /// Makes the bytes of the picture of the camera, off the main actor.
    private func use(_ image: UIImage) {
        let receive = onPictureStart()
        loading = true
        Task {
            let data = await CameraPicture.data(of: image)
            loading = false
            receive(.data(data ?? Data()))
        }
    }
}

/// The icon and the text of a photo button, as a text button of the system: the icon in the colour of the text, at
/// the size of the text.
private struct PhotoButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.s2) {
            configuration.icon
                .imageScale(.medium)
            configuration.title
                .multilineTextAlignment(.leading)
        }
        .font(Typography.label)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}
