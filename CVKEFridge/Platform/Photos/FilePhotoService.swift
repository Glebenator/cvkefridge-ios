import CVKEFridgeFeatures
import Foundation
import UIKit

/// The photos of the products as files in the folder of the app (`PhotoStore`), and the pictures of those files for
/// the screens (`PhotoLoader`).
///
/// - A photo is a JPEG with its longest edge at `PhotoFiles.maxEdge` pixels or less, with no metadata
///   (`PhotoEncoder`). The service makes the JPEG off the main actor and outside the store, so that one large picture
///   does not stop the other work of the store. Then the store writes the file in one step.
/// - A change of the photo keeps the earlier photo as a removed photo, so that "Undo" can bring it back. For the first
///   photo of a product, `replace` is the same as `save`: there is no earlier photo.
/// - The pictures for the screens are decoded at the size of their box, off the main actor, and kept in memory with a
///   limit in bytes. A memory warning of the system empties the memory. A new photo of a product has a new file, so a
///   picture in memory is never old. The pictures of the earlier files of a product go when its photo changes.
/// - The service writes no names and no pictures to a log.
final class FilePhotoService: PhotoService, @unchecked Sendable {
    // The stored values are constants of `Sendable` types, except the observer, which only `deinit` uses.

    private let store: PhotoStore
    private let loader: PhotoLoader<UIImage>
    private let memoryWarnings: NSObjectProtocol

    /// - Parameter directory: The folder of the photos. The prepared photos of the add forms are in a folder next to
    ///   it.
    init(directory: URL) {
        store = PhotoStore(directory: directory)
        let loader = PhotoLoader<UIImage>(
            costLimit: PhotoLoader<UIImage>.costLimit(physicalMemory: ProcessInfo.processInfo.physicalMemory)
        ) { url, side in
            guard let image = PhotoEncoder.thumbnail(at: url, filling: side) else {
                return nil
            }
            return (UIImage(cgImage: image), cost: image.bytesPerRow * image.height)
        }
        self.loader = loader
        // The pictures in memory can be decoded again. The photos on the screen stay, because their views keep them.
        memoryWarnings = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { _ in
            loader.removeAll()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(memoryWarnings)
    }

    func start() async -> [String: ProductPhoto] {
        // A folder that cannot be read now gives no photos. The store reads it again at the next call.
        await store.read()
        // The prepared photos of forms that closed with no save, older than one day.
        await store.cleanPrepared()
        return await store.photos
    }

    func setPhoto(productId: String, picture: PictureSource) async throws -> PhotoChange {
        let jpeg = try await Self.jpeg(of: picture)
        let change = try await store.replace(productId: productId) { url in
            try PhotoEncoder.write(jpeg, to: url)
        }
        loader.invalidate(productId: productId, keeping: change.photo.url)
        return change
    }

    func undo(_ change: PhotoChange, productId: String) async -> ProductPhoto? {
        _ = await store.undo(change)
        let photo = await store.photos[productId]
        loader.invalidate(productId: productId, keeping: photo?.url)
        return photo
    }

    func removePhoto(productId: String) async throws -> RemovedPhoto? {
        let removed = try await store.remove(productId: productId)
        loader.invalidate(productId: productId)
        return removed
    }

    func restore(_ removed: RemovedPhoto) async -> ProductPhoto? {
        _ = await store.restore(removed)
        let photo = await store.photos[removed.productId]
        loader.invalidate(productId: removed.productId, keeping: photo?.url)
        return photo
    }

    func release(_ removed: RemovedPhoto) async {
        await store.release(removed)
    }

    func release(_ change: PhotoChange) async {
        await store.release(change)
    }

    func prepare(picture: PictureSource) async throws -> PreparedPhoto {
        let jpeg = try await Self.jpeg(of: picture)
        return try await store.prepare { url in
            try PhotoEncoder.write(jpeg, to: url)
        }
    }

    func url(of prepared: PreparedPhoto) async -> URL? {
        await store.url(of: prepared)
    }

    func adopt(productId: String, prepared: PreparedPhoto) async throws -> ProductPhoto {
        let photo = try await store.adopt(productId: productId, prepared: prepared)
        loader.invalidate(productId: productId, keeping: photo.url)
        return photo
    }

    func discard(_ prepared: PreparedPhoto) async {
        await store.discard(prepared)
    }

    func clean(productIds: Set<String>) async {
        let before = await store.photos
        await store.clean(productIds: productIds)
        for productId in before.keys where !productIds.contains(productId) {
            loader.invalidate(productId: productId)
        }
    }

    func cachedImage(at url: URL, pixelSize: Int) -> UIImage? {
        loader.cached(url, pixelSize: pixelSize)
    }

    func image(at url: URL, pixelSize: Int) async -> UIImage? {
        await loader.load(url, pixelSize: pixelSize)
    }

    // MARK: A photo from a picture

    /// The JPEG of the photo of a picture, made off the main actor. The picture is read one time. A file that the app
    /// made for the camera is deleted after the read, also when the read fails.
    @concurrent
    private static func jpeg(of picture: PictureSource) async throws -> Data {
        switch picture {
        case .data(let data):
            return try PhotoEncoder.jpeg(from: data)
        case .file(let file, let deleteAfterUse):
            defer {
                if deleteAfterUse {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            return try PhotoEncoder.jpeg(contentsOf: file)
        }
    }
}
