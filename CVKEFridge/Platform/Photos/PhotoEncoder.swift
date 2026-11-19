// The photo of a product from a picture, and the small pictures of a photo for the screens. The Android file
// `app/src/main/java/com/cvke/fridge/photo/PhotoEncoder.kt` in cvkefridge-android has the same result, with
// `ImageDecoder` in the place of ImageIO. The decode for the screens is the decode of
// `app/src/main/java/com/cvke/fridge/photo/PhotoLoader.kt`.
//
// This file is in the app, not in `CVKEFridgeCore`, because it uses ImageIO and CoreGraphics. The package uses
// Foundation only.
import CoreGraphics
import CVKEFridgeFeatures
import Foundation
import ImageIO

/// Makes the JPEG of a product photo from a picture that the person selected or took, and decodes the small pictures
/// of a photo for the screens. Each function reads its picture one time and keeps no reference to it. Each function
/// is safe to call off the main actor, and each one does its work on the thread of the call.
///
/// - The photo has its longest edge at `PhotoFiles.maxEdge` pixels or less. ImageIO decodes the picture directly at
///   that size, so a very large picture, for example a panorama, needs little memory: no bitmap of the full size is
///   made. A smaller picture keeps its size.
/// - ImageIO turns the picture as its orientation says, so the photo shows upright with no orientation value.
/// - The JPEG has the quality `PhotoFiles.quality` and no metadata: the location, the time, the camera, and the notes
///   of the maker do not go into it. Only the pixels go into the file.
/// - JPEG has no transparency. A transparent part becomes white. The colours are in sRGB.
/// - The app writes the file in one step (`write(_:to:)`): the file is complete or not there. It has file protection.
enum PhotoEncoder {
    /// The picture is not a picture that the app can read: no data, a type that ImageIO does not know, a damaged file,
    /// or a picture that is too large.
    struct PictureCannotBeRead: Error, Sendable {
        init() {}
    }

    /// The largest picture that the app reads, in pixels: 400 megapixels. A larger picture is not a photo of a food,
    /// and its decode can use too much memory. A panorama of an iPhone has less than 70 megapixels.
    static let maxPicturePixels = 400_000_000

    /// The JPEG of the photo of a picture.
    ///
    /// - Parameter picture: The bytes of a picture file: JPEG, HEIC, PNG, or each other type of ImageIO.
    /// - Throws: `PictureCannotBeRead` when the bytes are not a picture that the app can read.
    static func jpeg(from picture: Data) throws -> Data {
        guard !picture.isEmpty,
              let source = CGImageSourceCreateWithData(picture as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else {
            throw PictureCannotBeRead()
        }
        return try jpeg(from: source)
    }

    /// The JPEG of the photo of a picture file.
    ///
    /// - Throws: `PictureCannotBeRead` when the file is not a picture that the app can read.
    static func jpeg(contentsOf file: URL) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw PictureCannotBeRead()
        }
        return try jpeg(from: source)
    }

    /// Writes the bytes of a photo into a new file, in one step, with file protection. The file can be read only after
    /// the person unlocks the device. A file that is open stays available when the device locks during the write.
    static func write(_ jpeg: Data, to url: URL) throws {
        #if os(iOS)
        try jpeg.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        #else
        try jpeg.write(to: url, options: .atomic)
        #endif
    }

    /// The picture of a photo file for a square box of `side` x `side` pixels that the picture fills: the short edge
    /// is at least `side`, and the box crops the rest. A photo that is smaller than the box keeps its size. Nil when
    /// the file cannot be decoded.
    static func thumbnail(at url: URL, filling side: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              case let (width, height)? = pixelSize(of: source)
        else {
            return nil
        }
        let longest = max(width, height)
        let shortest = min(width, height)
        // The longest edge that gives the short edge the side of the box.
        let wanted = (Double(max(side, 1)) * Double(longest) / Double(shortest)).rounded(.up)
        let maxPixelSize = Int(min(wanted, Double(longest)))
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixelSize: maxPixelSize))
    }

    // MARK: Private

    private static func jpeg(from source: CGImageSource) throws -> Data {
        guard CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetCount(source) > 0,
              case let (width, height)? = pixelSize(of: source),
              width * height <= maxPicturePixels,
              let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixelSize: PhotoFiles.maxEdge)),
              let opaque = onWhite(decoded)
        else {
            throw PictureCannotBeRead()
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            throw PictureCannotBeRead()
        }
        // The image has no properties of the picture. Only the pixels and the quality go into the file.
        let properties = [kCGImageDestinationLossyCompressionQuality: Double(PhotoFiles.quality) / 100] as CFDictionary
        CGImageDestinationAddImage(destination, opaque, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw PictureCannotBeRead()
        }
        return output as Data
    }

    /// The width and the height of the first picture of the source, before its orientation, or nil when the source
    /// gives no size.
    private static func pixelSize(of source: CGImageSource) -> (Int, Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0
        else {
            return nil
        }
        return (width, height)
    }

    /// The options that decode a picture with its longest edge at `maxPixelSize` or less, turned as its orientation
    /// says. The decode always uses the full picture, not a small preview in the file. It occurs now, on the thread
    /// of the call, and not later when the screen draws the picture.
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
        context.interpolationQuality = .high
        context.draw(image, in: box)
        return context.makeImage()
    }
}
