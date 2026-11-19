import CVKEFridgeFeatures
import Foundation
import Observation
import UIKit

/// The photos of the products and the photos of the add forms. `FridgeModel` owns one coordinator, and the screens read
/// its values through the model.
///
/// The coordinator keeps the photo state and the photo files that a save owns. The model keeps the messages with
/// "Undo" and "Try again", and the protections of the photo files that their buttons need: it decides which products
/// the cleanup keeps (`clean(keeping:)`) and when a removed or a changed photo is released.
@Observable
@MainActor
final class PhotoCoordinator {
    /// The photo of each product that has one, by the identifier of the product.
    private(set) var photos: [String: ProductPhoto] = [:]

    /// The products that get a new photo now. The screen of the food says "Adding the photo…".
    private(set) var photoImports: Set<String> = []

    /// The photo of each add form that has one, by the token of the form.
    private(set) var formPhotos: [String: FormPhoto] = [:]

    /// Shows a message, for example when a picture cannot be read. The model sets it.
    @ObservationIgnored var onMessage: (@MainActor (NoticeMessage) -> Void)?

    @ObservationIgnored private let service: any PhotoService
    /// The photo import that runs for an add form, by the token of the form.
    @ObservationIgnored private var formPhotoImports: [String: FormPhotoImport] = [:]
    /// The number of the newest photo import of an add form.
    @ObservationIgnored private var formPhotoGeneration = 0
    /// The prepared photos of the add forms that a save owns, from the call of `FridgeModel.perform` to the end of the
    /// save. The form does not delete them.
    @ObservationIgnored private var photosInSave: Set<PreparedPhoto> = []

    /// A photo import of an add form that did not end.
    private struct FormPhotoImport {
        /// The number of the import. Only the import with the number in `formPhotoImports` can change the form.
        let generation: Int
        /// The work that makes the photo, or nil while the picture loads (`startFormPhoto(token:)`).
        let task: Task<Void, Never>?
        /// The photo that the form had before the import, or nil.
        let earlier: FormPhoto?
    }

    init(service: any PhotoService) {
        self.service = service
    }

    /// Reads the folder of the photos. The model calls it one time, at its start.
    func start() async {
        photos = await service.start()
    }

    // MARK: - The photo of a product

    /// "Adding the photo…" shows for the product from this call until `importEnded(_:)`.
    func importStarted(_ productId: String) {
        photoImports.insert(productId)
    }

    func importEnded(_ productId: String) {
        photoImports.remove(productId)
    }

    /// Makes the photo of the product from the picture, and replaces the photo that the product had.
    func setPhoto(productId: String, picture: PictureSource) async throws -> PhotoChange {
        let change = try await service.setPhoto(productId: productId, picture: picture)
        photos[productId] = change.photo
        return change
    }

    /// Removes the photo of the product. The result is nil when the product has no photo.
    func removePhoto(productId: String) async throws -> RemovedPhoto? {
        guard let removed = try await service.removePhoto(productId: productId) else {
            return nil
        }
        photos[productId] = nil
        return removed
    }

    /// Brings back a removed photo: the "Undo" of a remove.
    func restore(_ removed: RemovedPhoto) async {
        photos[removed.productId] = await service.restore(removed)
    }

    /// Brings back the photo that a product had before a change of its photo.
    func undo(_ change: PhotoChange, productId: String) async {
        photos[productId] = await service.undo(change, productId: productId)
    }

    /// Gives the product the prepared photo of the add form again, after it could not get it: "Try again".
    func adoptAgain(_ photo: PreparedPhoto, productId: String) async throws {
        photos[productId] = try await service.adopt(productId: productId, prepared: photo)
    }

    /// The message with "Undo" of a removed photo closed.
    func release(_ removed: RemovedPhoto) async {
        await service.release(removed)
    }

    /// The message with "Undo" of a changed photo closed.
    func release(_ change: PhotoChange) async {
        await service.release(change)
    }

    /// Deletes a prepared photo that no product got and no message needs.
    func discard(_ photo: PreparedPhoto) async {
        await service.discard(photo)
    }

    /// Deletes the photos of the products that are not in `productIds`, and the files that no photo needs.
    func clean(keeping productIds: Set<String>) async {
        await service.clean(productIds: productIds)
        photos = photos.filter { productIds.contains($0.key) }
    }

    // MARK: - The photo of an add form

    /// Makes the photo of the add form with the `token` from the picture, off the main actor. The product does not
    /// exist yet: give `formPhoto(_:)` to `FridgeModel.perform`, and the product gets the photo after the save. A
    /// picture that cannot be read gives a message, and the form keeps the photo that it had.
    ///
    /// Each call starts a new import for the token. An import that a newer call or `discardFormPhoto(token:)`
    /// replaced does not change the form when it ends: it deletes its prepared file, and it shows no message.
    func makeFormPhoto(token: String, picture: PictureSource) {
        makeFormPhoto(token: token, load: startFormPhoto(token: token), picture: picture)
    }

    /// The person selected or took a picture for the add form with the `token`, and its bytes load now, for example
    /// from iCloud. From this call, the photo of the form is `making`: "Save" is off, and the form says why. Give the
    /// result to `makeFormPhoto(token:load:picture:)` when the bytes are there.
    ///
    /// A newer call, a newer import, or `discardFormPhoto(token:)` replaces the load. For example, "Save and add
    /// another" discards the photo of the saved food. The picture of a replaced load then does nothing, so it never
    /// goes to the next food of the form.
    func startFormPhoto(token: String) -> FormPhotoLoad {
        // The photo that the form shows when this import fails. A newer import keeps the photo of the import before
        // it, because the photo of the form while an import runs is `making`.
        let earlier: FormPhoto?
        if let running = formPhotoImports.removeValue(forKey: token) {
            running.task?.cancel()
            earlier = running.earlier
        } else {
            earlier = formPhotos[token]
        }
        formPhotoGeneration += 1
        formPhotos[token] = .making
        formPhotoImports[token] = FormPhotoImport(generation: formPhotoGeneration, task: nil, earlier: earlier)
        return FormPhotoLoad(generation: formPhotoGeneration)
    }

    /// Makes the photo of the add form from the picture of a load that `startFormPhoto(token:)` started. The picture
    /// of a load that was replaced does nothing.
    func makeFormPhoto(token: String, load: FormPhotoLoad, picture: PictureSource) {
        guard let running = formPhotoImports[token], running.generation == load.generation, running.task == nil else {
            return
        }
        let generation = load.generation
        let earlier = running.earlier
        let task = Task {
            let prepared: PreparedPhoto
            do {
                prepared = try await service.prepare(picture: picture)
            } catch {
                guard formPhotoImports[token]?.generation == generation else {
                    return
                }
                formPhotoImports[token] = nil
                formPhotos[token] = earlier
                onMessage?(.photoFailed)
                return
            }
            let url = await service.url(of: prepared)
            guard formPhotoImports[token]?.generation == generation else {
                // The form discarded this import, or a newer import replaced it. No form shows this file.
                await service.discard(prepared)
                return
            }
            // The form shows the new photo before the earlier photo goes. There is no wait between the check above
            // and this change, so a form that closes while the earlier photo goes finds the new photo and deletes it.
            formPhotoImports[token] = nil
            formPhotos[token] = .ready(prepared, url: url)
            // A save that owns the earlier photo decides about its file.
            if case .ready(let old, _) = earlier, !photosInSave.contains(old) {
                await service.discard(old)
            }
        }
        formPhotoImports[token] = FormPhotoImport(generation: generation, task: task, earlier: earlier)
    }

    /// The photo of the add form with the `token` that is ready, or nil.
    func formPhoto(_ token: String) -> PreparedPhoto? {
        if case .ready(let photo, _) = formPhotos[token] {
            return photo
        }
        return nil
    }

    /// Deletes the photo of the add form with the `token`: the person removed it, or the form closed with no save.
    ///
    /// An import that runs for the form stops. When it ends, it deletes its prepared file. A picture that loads for
    /// the form does nothing when it arrives. The photo of a save that runs stays: the save owns its file.
    func discardFormPhoto(token: String) {
        var discarded: [PreparedPhoto] = []
        if let running = formPhotoImports.removeValue(forKey: token) {
            running.task?.cancel()
            // The photo before the import is not on the form now, and no later import gets it.
            if case .ready(let photo, _) = running.earlier {
                discarded.append(photo)
            }
        }
        if case .ready(let photo, _) = formPhotos.removeValue(forKey: token) {
            discarded.append(photo)
        }
        discarded.removeAll { photosInSave.contains($0) }
        guard !discarded.isEmpty else {
            return
        }
        Task {
            for photo in discarded {
                await service.discard(photo)
            }
        }
    }

    /// The picture of a photo file that is ready in memory for a box of `pixelSize` pixels, or nil.
    func cachedImage(of photo: ProductPhoto, pixelSize: Int) -> UIImage? {
        service.cachedImage(at: photo.url, pixelSize: pixelSize)
    }

    /// Decodes the picture of a photo file for a box of `pixelSize` pixels, off the main actor. Nil when the file
    /// cannot be decoded.
    func image(of photo: ProductPhoto, pixelSize: Int) async -> UIImage? {
        await service.image(at: photo.url, pixelSize: pixelSize)
    }

    // MARK: - The photo of a save

    /// A save owns the prepared photo from the call of `FridgeModel.perform` to the end of the save.
    func saveStarted(_ photo: PreparedPhoto) {
        photosInSave.insert(photo)
    }

    /// Gives the photo of the add form to the product that the form saved. After the call, the form does not show
    /// the photo. The result is false when the product could not get the photo: the prepared file then stays, and the
    /// caller keeps it for "Try again".
    func adopt(_ photo: PreparedPhoto, productId: String, formToken: String?) async -> Bool {
        var adopted = true
        do {
            photos[productId] = try await service.adopt(productId: productId, prepared: photo)
        } catch {
            adopted = false
        }
        photosInSave.remove(photo)
        if let formToken, formPhoto(formToken) == photo {
            formPhotos[formToken] = nil
        }
        return adopted
    }

    /// The save of a photo ended, and no product got the photo. The form keeps the photo for its next "Save". When
    /// the form does not have the photo now (it closed, or it got a different photo), the file goes.
    func endSave(of photo: PreparedPhoto, formToken: String?) async {
        photosInSave.remove(photo)
        if let formToken, formHas(photo, token: formToken) {
            return
        }
        await service.discard(photo)
    }

    /// True when the add form shows the photo, or shows it again when the import that runs fails.
    private func formHas(_ photo: PreparedPhoto, token: String) -> Bool {
        if formPhoto(token) == photo {
            return true
        }
        if case .ready(let earlier, _) = formPhotoImports[token]?.earlier {
            return earlier == photo
        }
        return false
    }
}
