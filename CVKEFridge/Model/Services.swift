import CVKEFridgeFeatures
import Foundation
import UIKit

// The services that `FridgeModel` uses for the parts of the app that need the system: the network, the notifications,
// the photo files, and the camera. Each is a protocol, and the model gets an implementation through its initializer.
// A test gives its own implementation.
//
// Each protocol has one implementation in `Platform/`, in the folder of the feature:
//
// | Protocol | Implementation | File |
// | --- | --- | --- |
// | `ProductLookupService` | `OpenFoodFactsLookupService` | `Platform/Lookup/OpenFoodFactsLookupService.swift` |
// | `ReminderService` | `LocalReminderService` | `Platform/Reminders/LocalReminderService.swift` |
// | `PhotoService` | `FilePhotoService` | `Platform/Photos/FilePhotoService.swift` |
// | `CameraAvailability` | `SystemCamera` | `Platform/Scanner/SystemCamera.swift` |
//
// To change how a feature uses the system, change its implementation file. `FridgeModel` does not change.

// MARK: - The product lookup

/// The answer of a product lookup: the barcode that the answer is for, and the result.
struct ProductLookupAnswer: Hashable, Sendable {
    /// The barcode of the result, in the form of `Barcodes`. It is one of the barcodes of the request.
    let barcode: String
    let result: LookupResult
}

/// Looks up the product of a barcode: first the cache on the phone, then Open Food Facts.
protocol ProductLookupService: Sendable {
    /// Looks up the product of a barcode.
    ///
    /// `barcodes` has the barcode in the form of `Barcodes`. For eight typed digits that can be an EAN-8 and a UPC-E,
    /// it has the two barcodes (`Barcodes.typedCandidates`). The service tries the cache with each of them, in their
    /// order, before it uses the network. The request to the network is for the first barcode only.
    ///
    /// - Parameter barcodes: One barcode or more. The list is not empty.
    /// - Throws: `CancellationError` when the task is cancelled.
    func find(_ barcodes: [String]) async throws(CancellationError) -> ProductLookupAnswer
}

// MARK: - The reminders

/// The notifications of the daily reminder. The model decides which reminders there are (`ReminderPlan`), and this
/// service shows them with the system.
///
/// iOS does not start the code of the app at the time of a reminder. So the model plans the reminders of the next
/// days, and plans them again after each change of the inventory or of the settings, at each start, and after each
/// change of the clock or the time zone.
protocol ReminderService: Sendable {
    /// If iOS shows the notifications of the app.
    func access() async -> NotificationAccess

    /// Asks iOS for the notification permission. iOS shows its question only the first time. Explain the reminders to
    /// the person before this call. The result is the access after the answer.
    func requestAccess() async -> NotificationAccess

    /// Shows the reminders of the model with the system. The model calls it after each change of the inventory or of
    /// the settings, at each start, and after each change of the day, the clock, or the time zone.
    ///
    /// - Parameters:
    ///   - planned: The reminders of the next days. They replace all reminders that were planned before. An empty
    ///     list removes them: reminders are off, or no food needs a reminder.
    ///   - todayFoods: The foods that a reminder of today names now, or an empty list. A reminder in the
    ///     Notification Center that names other food is old: for example, the person used the food after the
    ///     reminder came. With an empty list, the service removes the reminder from the Notification Center.
    ///   - timeZone: The time zone of the device now, for the instant of each reminder.
    func update(planned: [PlannedReminder], todayFoods: [ReminderFood], timeZone: TimeZone) async

    /// One value for each tap of the person on a reminder, also for the tap that started the app. The model then
    /// shows My Fridge with the food that is expiring or expired. Call it one time.
    func taps() -> AsyncStream<Void>
}

// MARK: - The photos

/// A picture that the person selected or took, before the app makes a photo from it.
enum PictureSource: Sendable {
    /// The bytes of a picture file, for example from the photo picker.
    case data(Data)
    /// A picture file. The app reads it one time. `deleteAfterUse` is true for a file that the app made for the
    /// camera: the service deletes it after the read.
    case file(URL, deleteAfterUse: Bool)
}

/// The photos of the products: files in the folder of the app. The core has no photo yet, so a photo is not in the
/// change log.
///
/// The service makes a photo from a picture off the main actor: it reads the picture one time, makes it smaller
/// (`PhotoFiles.maxEdge`), and writes a JPEG with no metadata. It keeps no reference to the picture of the person. It
/// writes no names or pictures to a log.
///
/// A photo that the person removed or replaced stays as a file while its message with "Undo" is on the screen. The
/// model calls `release` when that message closes, and `clean` then deletes the file. So the cleanup after one
/// message never deletes the photo that the "Undo" of a different message needs.
protocol PhotoService: Sendable {
    /// Reads the folder of the photos, and deletes the old files of forms that closed with no save. The result is the
    /// photo of each product that has one. The model calls it one time, at the start.
    func start() async -> [String: ProductPhoto]

    /// Makes the photo of the product from the picture. The result has the new photo, and the photo that the product
    /// had before as a removed photo, so that `undo(_:productId:)` can bring it back.
    ///
    /// - Throws: An error when the picture cannot be read or the photo cannot be written. The product then keeps the
    ///   photo that it had.
    func setPhoto(productId: String, picture: PictureSource) async throws -> PhotoChange

    /// Undoes a `setPhoto`: the new photo goes, and the earlier photo comes back. A product that got a different
    /// photo after the change keeps that photo.
    ///
    /// - Returns: The photo of the product after the call, or nil when it has none.
    func undo(_ change: PhotoChange, productId: String) async -> ProductPhoto?

    /// Removes the photo of the product. The file stays as a removed photo. The result is nil when the product has
    /// no photo.
    ///
    /// - Throws: An error when the file cannot be changed.
    func removePhoto(productId: String) async throws -> RemovedPhoto?

    /// Brings back a removed photo: the "Undo" of a remove. A product that got a new photo after the remove keeps the
    /// new photo.
    ///
    /// - Returns: The photo of the product after the call, or nil when it has none.
    func restore(_ removed: RemovedPhoto) async -> ProductPhoto?

    /// The message with "Undo" of a removed photo closed. The next `clean` deletes its file.
    func release(_ removed: RemovedPhoto) async

    /// The message with "Undo" of a changed photo closed. The next `clean` deletes the file of the earlier photo.
    func release(_ change: PhotoChange) async

    /// Makes a photo for a product that does not exist yet: the photo of the add form.
    ///
    /// - Throws: An error when the picture cannot be read or the photo cannot be written.
    func prepare(picture: PictureSource) async throws -> PreparedPhoto

    /// The file of a prepared photo, to show it in the add form, or nil when it is not there.
    func url(of prepared: PreparedPhoto) async -> URL?

    /// Makes a prepared photo the photo of the product, after the form saved the product.
    ///
    /// - Throws: An error when the prepared file cannot be read or the photo cannot be written.
    func adopt(productId: String, prepared: PreparedPhoto) async throws -> ProductPhoto

    /// Deletes a prepared photo that no product got.
    func discard(_ prepared: PreparedPhoto) async

    /// Deletes each file that no product needs: the photos of the products that are not in `productIds`, the removed
    /// and replaced photos that are released, and the files of a write that stopped. Give in `productIds` also each
    /// deleted product that an "Undo" on the screen can bring back.
    func clean(productIds: Set<String>) async

    /// The picture of a photo file that is ready in memory for a box of `pixelSize` pixels, or nil. A list that
    /// scrolls back then shows the photo in its first frame.
    nonisolated func cachedImage(at url: URL, pixelSize: Int) -> UIImage?

    /// Decodes the picture of a photo file for a box of `pixelSize` pixels, off the main actor, and keeps it in
    /// memory. Nil when the file cannot be decoded.
    func image(at url: URL, pixelSize: Int) async -> UIImage?
}

// MARK: - The camera

/// What iOS says about the camera permission of the app.
enum CameraAccess: Hashable, Sendable, CaseIterable {
    /// The device has no camera.
    case noCamera
    /// The app did not ask yet. Explain the camera to the person, then ask.
    case ask
    /// The person did not allow the camera. Only the Settings app can change it.
    case blocked
    case allowed
}

/// If the app can use the camera, for the scanner and for "Take a photo". The scanner and the photo sources also work
/// with no camera: the person can type the barcode and choose a photo.
protocol CameraAvailability: Sendable {
    /// The camera access now.
    func access() -> CameraAccess

    /// Asks iOS for the camera permission. iOS shows its question only the first time. The result is the access after
    /// the answer.
    func requestAccess() async -> CameraAccess
}
