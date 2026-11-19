import Foundation

// The rules for the files of the product photos. The Android file
// `app/src/main/java/com/cvke/fridge/photo/PhotoFiles.kt` in cvkefridge-android has the same behaviour, with one
// correction (a box with no size does not stop the sample size).

/// The photo of a product, as a file in the files of the app. A new photo of the product has a new file, so a file
/// names one picture.
public struct ProductPhoto: Hashable, Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

/// A photo that the person removed or replaced. Its file stays, with the end `PhotoFiles.removed`, until the message
/// with "Undo" closes and the app calls `PhotoStore.release(_:)`. Then `PhotoStore.clean(productIds:)` deletes it.
public struct RemovedPhoto: Hashable, Sendable {
    public let productId: String
    /// The name of the removed file in the folder of the photos.
    public let fileName: String

    public init(productId: String, fileName: String) {
        self.productId = productId
        self.fileName = fileName
    }
}

/// A change of the photo of a product with `PhotoStore.replace`: the new photo, and the earlier photo as a removed
/// photo, or nil when the product had no photo. `PhotoStore.undo(_:)` brings the earlier photo back.
/// `PhotoStore.release(_:)` ends its protection when the message with "Undo" closes.
public struct PhotoChange: Hashable, Sendable {
    public let photo: ProductPhoto
    public let earlier: RemovedPhoto?

    public init(photo: ProductPhoto, earlier: RemovedPhoto?) {
        self.photo = photo
        self.earlier = earlier
    }
}

/// A photo of the add form for a product that does not exist yet (see `PhotoStore.prepare(encode:)`). The form keeps
/// it, also when the system stops the app in the background. It has the name of the file, not its path: the path of
/// the folders of an iOS app can change after an update.
public struct PreparedPhoto: Hashable, Sendable, Codable {
    /// The name of the file in the folder of the prepared photos.
    public let fileName: String

    public init(fileName: String) {
        self.fileName = fileName
    }
}

/// A file in the folder of the photos, with the time of its last change.
public struct PhotoFile: Hashable, Sendable {
    public let name: String
    public let modified: Date

    public init(name: String, modified: Date) {
        self.name = name
        self.modified = modified
    }
}

/// The rules for the files of the product photos. The core has no photo yet, so the app keeps the photos in its own
/// folder, with one file for each product: `<product>.<token>.jpg`. The product is the identifier of the product, and
/// the token is random, so that a new photo of a product has a new name. The shared specification must get a rule for
/// the photo of a product before the photos can go into the change log.
public enum PhotoFiles {
    /// The end of the name of a photo. The app writes each photo as a JPEG.
    public static let fileExtension = ".jpg"

    /// The end of the name of a photo that the app writes now. The file gets its name when it is complete.
    public static let temporary = ".tmp"

    /// The end of the name of a photo that the person removed.
    public static let removed = ".removed"

    /// The longest edge of a photo, in pixels. A larger picture is made smaller. A phone screen needs no more.
    public static let maxEdge = 1024

    /// The JPEG quality of a photo, from 0 to 100. ImageIO uses 0.85.
    public static let quality = 85

    /// The name of the file of a photo of the product. Each part must be an identifier of the rules of the core: 1 to
    /// 64 of the characters a to z, 0 to 9, and "-".
    public static func name(productId: String, token: String) -> String {
        precondition(isIdentifier(productId) && isIdentifier(token), "Not an identifier")
        return "\(productId).\(token)\(fileExtension)"
    }

    /// The product of the file with this name, or nil when the name is not the name of a photo.
    public static func productOf(_ name: String) -> String? {
        guard name.hasSuffix(fileExtension) else {
            return nil
        }
        let parts = name.dropLast(fileExtension.count).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ isIdentifier(String($0)) }) else {
            return nil
        }
        return String(parts[0])
    }

    /// The photo of each product in the folder. When a product has more than one file, for example after a stop of
    /// the app during a change of its photo, the newest file is its photo. With the same time, the last name.
    public static func current(_ files: [PhotoFile]) -> [String: String] {
        var newest: [String: PhotoFile] = [:]
        for file in files {
            guard let product = productOf(file.name) else {
                continue
            }
            if let other = newest[product],
               other.modified > file.modified || (other.modified == file.modified && other.name >= file.name) {
                continue
            }
            newest[product] = file
        }
        return newest.mapValues(\.name)
    }

    /// The files that no product needs: a file that is not a photo (a temporary file, a removed photo, or another
    /// file), a photo of a product that is not in `productIds`, and a file of a product that is not its photo in
    /// `current`. The order of `names` stays.
    public static func unwanted(_ names: [String], current: [String: String], productIds: Set<String>) -> [String] {
        names.filter { name in
            guard let product = productOf(name) else {
                return true
            }
            return !productIds.contains(product) || current[product] != name
        }
    }

    /// The size of a photo for a picture of `width` x `height` pixels: the same shape, with the longest edge not more
    /// than `maxEdge`. A smaller picture keeps its size. The two values must be more than 0.
    public static func targetSize(width: Int, height: Int, maxEdge: Int = maxEdge) -> (width: Int, height: Int) {
        precondition(width > 0 && height > 0, "The picture has no size")
        let longest = max(width, height)
        if longest <= maxEdge {
            return (width, height)
        }
        let scale = Double(maxEdge) / Double(longest)
        return (max(1, roundHalfUp(Double(width) * scale)), max(1, roundHalfUp(Double(height) * scale)))
    }

    /// The sample size for a decode of a photo of `width` x `height` pixels that fills a box of `boxWidth` x
    /// `boxHeight` pixels: the largest power of 2 that keeps each edge as large as the box or larger. The box crops the
    /// rest. A box edge of less than 1 pixel counts as 1 pixel.
    public static func sampleSize(width: Int, height: Int, boxWidth: Int, boxHeight: Int) -> Int {
        let boxWidth = max(boxWidth, 1)
        let boxHeight = max(boxHeight, 1)
        var sample = 1
        while width / (sample * 2) >= boxWidth && height / (sample * 2) >= boxHeight {
            sample *= 2
        }
        return sample
    }

    /// The rounding of `Math.round`: to the nearest whole number, and a half up.
    private static func roundHalfUp(_ value: Double) -> Int {
        Int((value + 0.5).rounded(.down))
    }

    private static func isIdentifier(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        return (1...64).contains(scalars.count) && scalars.allSatisfy { scalar in
            ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) || scalar == "-"
        }
    }
}
