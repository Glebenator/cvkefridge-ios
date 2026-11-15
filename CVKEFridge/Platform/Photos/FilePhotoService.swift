import CVKEFridgeFeatures
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// The photos of the products as files in the folder of the app (`PhotoStore`), and the pictures of those files for
/// the screens.
///
/// - A photo is a JPEG with its longest edge at `PhotoFiles.maxEdge` pixels or less. ImageIO decodes the picture at
///   that size, so a very large picture needs little memory, and it turns the picture as its orientation says.
/// - The JPEG has no metadata: the location, the time, and the camera of the picture do not go into it.
/// - JPEG has no transparency. A transparent part becomes white.
/// - The pictures for the screens are decoded at the size of their box, off the main actor, and kept in memory.
///   A new photo of a product has a new file, so a picture in memory is never old.
final class FilePhotoService: PhotoService, @unchecked Sendable {
    // `NSCache` is safe to use from more than one thread. The other stored values are constants.

    /// A picture is not a picture that the app can read, or the photo could not be written.
    struct PictureFailure: Error, Sendable {}

    private let store: PhotoStore
    private let cache = NSCache<NSString, UIImage>()

    /// - Parameter directory: The folder of the photos. The prepared photos of the add forms are in a folder next to
    ///   it.
    init(directory: URL) {
        store = PhotoStore(directory: directory)
        // About 32 MB of decoded pictures.
        cache.totalCostLimit = 32 * 1024 * 1024
    }

    func start() async -> [String: ProductPhoto] {
        // A folder that cannot be read now gives no photos. The store reads it again at the next call.
        await store.read()
        await store.cleanPrepared()
        return await store.photos
    }

    func setPhoto(productId: String, picture: PictureSource) async throws -> PhotoChange {
        defer { Self.discard(picture) }
        // The photo that the product has stays as a removed photo, so that "Undo" can bring it back.
        return try await store.replace(productId: productId) { url in
            try Self.encode(picture, to: url)
        }
    }

    func undo(_ change: PhotoChange, productId: String) async -> ProductPhoto? {
        _ = await store.undo(change)
        return await store.photos[productId]
    }

    func removePhoto(productId: String) async throws -> RemovedPhoto? {
        try await store.remove(productId: productId)
    }

    func restore(_ removed: RemovedPhoto) async -> ProductPhoto? {
        _ = await store.restore(removed)
        return await store.photos[removed.productId]
    }

    func release(_ removed: RemovedPhoto) async {
        await store.release(removed)
    }

    func release(_ change: PhotoChange) async {
        await store.release(change)
    }

    func prepare(picture: PictureSource) async throws -> PreparedPhoto {
        defer { Self.discard(picture) }
        return try await store.prepare { url in
            try Self.encode(picture, to: url)
        }
    }

    func url(of prepared: PreparedPhoto) async -> URL? {
        await store.url(of: prepared)
    }

    func adopt(productId: String, prepared: PreparedPhoto) async throws -> ProductPhoto {
        try await store.adopt(productId: productId, prepared: prepared)
    }

    func discard(_ prepared: PreparedPhoto) async {
        await store.discard(prepared)
    }

    func clean(productIds: Set<String>) async {
        await store.clean(productIds: productIds)
    }

    func cachedImage(at url: URL, pixelSize: Int) -> UIImage? {
        cache.object(forKey: Self.key(url, pixelSize))
    }

    func image(at url: URL, pixelSize: Int) async -> UIImage? {
        if let cached = cachedImage(at: url, pixelSize: pixelSize) {
            return cached
        }
        guard let image = await Self.decode(url, pixelSize: Self.bucket(pixelSize)) else {
            return nil
        }
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale) * 4
        cache.setObject(image, forKey: Self.key(url, pixelSize), cost: cost)
        return image
    }

    // MARK: Pictures for the screens

    /// The sizes of the boxes are put in steps, so that boxes of almost the same size use one picture.
    private static func bucket(_ pixelSize: Int) -> Int {
        var size = 64
        while size < pixelSize && size < PhotoFiles.maxEdge {
            size *= 2
        }
        return size
    }

    private static func key(_ url: URL, _ pixelSize: Int) -> NSString {
        "\(url.lastPathComponent)#\(bucket(pixelSize))" as NSString
    }

    @concurrent private static func decode(_ url: URL, pixelSize: Int) async -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixelSize: pixelSize))
        else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    // MARK: A photo from a picture

    /// Writes the photo of the picture into a new JPEG file.
    private static func encode(_ picture: PictureSource, to url: URL) throws {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        let source: CGImageSource?
        switch picture {
        case .data(let data):
            source = CGImageSourceCreateWithData(data as CFData, options)
        case .file(let file, _):
            source = CGImageSourceCreateWithURL(file as CFURL, options)
        }
        guard let source,
              let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixelSize: PhotoFiles.maxEdge)),
              let opaque = onWhite(decoded),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            throw PictureFailure()
        }
        // Only the pixels go into the file. The properties of the picture stay behind.
        let quality = Double(PhotoFiles.quality) / 100
        CGImageDestinationAddImage(destination, opaque, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw PictureFailure()
        }
    }

    /// The options that decode a picture at a size, turned as its orientation says. A smaller picture keeps its size.
    private static func thumbnailOptions(maxPixelSize: Int) -> CFDictionary {
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
    }

    /// The picture in sRGB on a white background, with no transparency.
    private static func onWhite(_ image: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: image.width,
                  height: image.height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else {
            return nil
        }
        let box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(box)
        context.draw(image, in: box)
        return context.makeImage()
    }

    /// Deletes the file of a picture that the app made for the camera.
    private static func discard(_ picture: PictureSource) {
        if case .file(let file, true) = picture {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
