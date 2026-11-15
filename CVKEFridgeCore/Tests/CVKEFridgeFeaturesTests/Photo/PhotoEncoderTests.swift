#if canImport(ImageIO)
import CoreGraphics
import CVKEFridgeFeatures
import Foundation
import ImageIO
import Testing

/// The photo of a picture: the size, the orientation, no metadata, no transparency, and the pictures that the app
/// cannot read. The pictures are made in the test with ImageIO.
struct PhotoEncoderTests {
    // MARK: Pictures of the test

    /// A picture with a red left half and a blue right half, as the pixels are in the file.
    private static func twoColours(width: Int, height: Int, alpha: Bool = false) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        if alpha {
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return context.makeImage()!
    }

    /// The bytes of a picture file of the `type`, with the `properties`.
    private static func file(_ image: CGImage, type: String, properties: [CFString: Any] = [:]) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data as CFMutableData, type as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// The properties of a camera picture: the location, the time, the camera, and the notes of the maker.
    private static var cameraProperties: [CFString: Any] { [
        kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: 47.37,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 8.54,
            kCGImagePropertyGPSLongitudeRef: "E",
        ],
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: "2026:11:14 12:00:00",
            kCGImagePropertyExifUserComment: "Private comment",
            kCGImagePropertyExifLensModel: "Test lens",
        ],
        kCGImagePropertyTIFFDictionary: [
            kCGImagePropertyTIFFMake: "Test maker",
            kCGImagePropertyTIFFModel: "Test phone",
            kCGImagePropertyTIFFDateTime: "2026:11:14 12:00:00",
        ],
        kCGImagePropertyIPTCDictionary: [
            kCGImagePropertyIPTCKeywords: ["Private keyword"],
        ],
        kCGImagePropertyMakerAppleDictionary: [
            "1": 15,
        ],
    ] }

    private struct Decoded {
        let image: CGImage
        let properties: [CFString: Any]
        let type: String
    }

    private static func decode(_ data: Data) throws -> Decoded {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let type = try #require(CGImageSourceGetType(source) as String?)
        return Decoded(image: image, properties: properties, type: type)
    }

    /// The colour of one pixel, as red, green, and blue from 0 to 255. `x` and `y` are from the top left.
    private static func pixel(_ image: CGImage, x: Int, y: Int) -> (red: Int, green: Int, blue: Int) {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &bytes,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        // The context has its origin at the bottom left.
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
    }

    private static func isRed(_ colour: (red: Int, green: Int, blue: Int)) -> Bool {
        colour.red > 200 && colour.green < 60 && colour.blue < 60
    }

    private static func isBlue(_ colour: (red: Int, green: Int, blue: Int)) -> Bool {
        colour.red < 60 && colour.green < 60 && colour.blue > 200
    }

    private static func isWhite(_ colour: (red: Int, green: Int, blue: Int)) -> Bool {
        colour.red > 240 && colour.green > 240 && colour.blue > 240
    }

    // MARK: Tests

    @Test func theOrientationOfThePictureIsApplied() throws {
        // Orientation 6: the picture shows turned 90 degrees clockwise. The left of the file is the top of the
        // picture.
        let picture = Self.file(
            Self.twoColours(width: 200, height: 100),
            type: "public.jpeg",
            properties: [kCGImagePropertyOrientation: 6]
        )
        let photo = try Self.decode(PhotoEncoder.jpeg(from: picture))
        #expect(photo.image.width == 100)
        #expect(photo.image.height == 200)
        #expect(Self.isRed(Self.pixel(photo.image, x: 50, y: 20)))
        #expect(Self.isBlue(Self.pixel(photo.image, x: 50, y: 180)))
        // The photo shows upright with no orientation value.
        #expect((photo.properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
    }

    @Test func aLargePictureGetsALongestEdgeOf1024Pixels() throws {
        let panorama = Self.file(Self.twoColours(width: 8000, height: 1000), type: "public.png")
        let photo = try Self.decode(PhotoEncoder.jpeg(from: panorama))
        #expect(photo.type == "public.jpeg")
        #expect(photo.image.width == PhotoFiles.maxEdge)
        #expect(photo.image.height == 128)

        let portrait = Self.file(Self.twoColours(width: 1500, height: 3000), type: "public.jpeg")
        let tall = try Self.decode(PhotoEncoder.jpeg(from: portrait))
        #expect(tall.image.width == 512)
        #expect(tall.image.height == 1024)
    }

    @Test func aSmallPictureKeepsItsSize() throws {
        let picture = Self.file(Self.twoColours(width: 300, height: 200), type: "public.png")
        let photo = try Self.decode(PhotoEncoder.jpeg(from: picture))
        #expect(photo.image.width == 300)
        #expect(photo.image.height == 200)
    }

    @Test func thePhotoHasNoMetadataOfThePicture() throws {
        let picture = Self.file(Self.twoColours(width: 1200, height: 900), type: "public.jpeg", properties: Self.cameraProperties)
        // The picture of the test has the metadata.
        let original = try Self.decode(picture)
        #expect(original.properties[kCGImagePropertyGPSDictionary] != nil)
        #expect(original.properties[kCGImagePropertyTIFFDictionary] != nil)

        let photo = try Self.decode(PhotoEncoder.jpeg(from: picture))
        #expect(photo.properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(photo.properties[kCGImagePropertyTIFFDictionary] == nil)
        #expect(photo.properties[kCGImagePropertyIPTCDictionary] == nil)
        #expect(photo.properties[kCGImagePropertyMakerAppleDictionary] == nil)
        let exif = photo.properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect(exif[kCGImagePropertyExifUserComment] == nil)
        #expect(exif[kCGImagePropertyExifLensModel] == nil)
        // Only the size and the colour space of the pixels can be in the Exif values of ImageIO.
        let allowed: Set<String> = [
            kCGImagePropertyExifPixelXDimension as String,
            kCGImagePropertyExifPixelYDimension as String,
            kCGImagePropertyExifColorSpace as String,
        ]
        #expect(Set(exif.keys.map { $0 as String }).isSubset(of: allowed))
    }

    @Test func aHEICPictureGivesAPhoto() throws {
        let heic = Self.file(Self.twoColours(width: 2000, height: 1500), type: "public.heic")
        let photo = try Self.decode(PhotoEncoder.jpeg(from: heic))
        #expect(photo.type == "public.jpeg")
        #expect(photo.image.width == 1024)
        #expect(photo.image.height == 768)
    }

    @Test func aTransparentPartBecomesWhite() throws {
        let picture = Self.file(Self.twoColours(width: 200, height: 100, alpha: true), type: "public.png")
        let photo = try Self.decode(PhotoEncoder.jpeg(from: picture))
        #expect(Self.isWhite(Self.pixel(photo.image, x: 40, y: 50)))
        #expect(Self.isBlue(Self.pixel(photo.image, x: 160, y: 50)))
    }

    @Test func dataThatIsNotAPictureFailsWithNoPhoto() throws {
        #expect(throws: PhotoEncoder.PictureCannotBeRead.self) {
            try PhotoEncoder.jpeg(from: Data())
        }
        #expect(throws: PhotoEncoder.PictureCannotBeRead.self) {
            try PhotoEncoder.jpeg(from: Data("This is not a picture".utf8))
        }
        // The start of a picture file, with no pixels. (ImageIO decodes the part that it can read of a damaged
        // picture. The person then sees that part, and can change the photo.)
        let picture = Self.file(Self.twoColours(width: 400, height: 300), type: "public.jpeg")
        #expect(throws: PhotoEncoder.PictureCannotBeRead.self) {
            try PhotoEncoder.jpeg(from: picture.prefix(20))
        }
        #expect(throws: PhotoEncoder.PictureCannotBeRead.self) {
            try PhotoEncoder.jpeg(contentsOf: URL(filePath: "/no-such-folder/picture.jpg"))
        }
    }

    @Test func aPictureFileGivesTheSamePhotoAsItsBytes() throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let picture = Self.file(Self.twoColours(width: 2048, height: 1024), type: "public.png")
        let file = folder.file("picture.png")
        try picture.write(to: file)
        let photo = try Self.decode(PhotoEncoder.jpeg(contentsOf: file))
        #expect(photo.image.width == 1024)
        #expect(photo.image.height == 512)
    }

    @Test func theWriteMakesTheCompleteFile() throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let jpeg = try PhotoEncoder.jpeg(from: Self.file(Self.twoColours(width: 64, height: 64), type: "public.png"))
        let target = folder.file("milk.t1.jpg")
        try PhotoEncoder.write(jpeg, to: target)
        #expect(try Data(contentsOf: target) == jpeg)
        #expect(folder.names() == ["milk.t1.jpg"])
    }

    @Test func aThumbnailFillsItsBox() throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let file = folder.file("milk.t1.jpg")
        try PhotoEncoder.write(
            PhotoEncoder.jpeg(from: Self.file(Self.twoColours(width: 1024, height: 512), type: "public.png")),
            to: file
        )
        // The short edge is the side of the box.
        let small = try #require(PhotoEncoder.thumbnail(at: file, filling: 128))
        #expect(small.width == 256)
        #expect(small.height == 128)
        // A box that is larger than the photo gets the photo at its size.
        let large = try #require(PhotoEncoder.thumbnail(at: file, filling: 1024))
        #expect(large.width == 1024)
        #expect(large.height == 512)
        #expect(PhotoEncoder.thumbnail(at: folder.file("none.jpg"), filling: 128) == nil)
    }
}
#endif
