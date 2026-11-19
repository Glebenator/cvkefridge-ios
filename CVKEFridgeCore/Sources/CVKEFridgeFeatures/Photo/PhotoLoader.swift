import Foundation
import Synchronization

// The pictures of the product photos for the screens, in memory. The Android file
// `app/src/main/java/com/cvke/fridge/photo/PhotoLoader.kt` in cvkefridge-android has the same task. The app gives the
// decode (`PhotoEncoder.thumbnail(at:filling:)`) and the type of the picture (`UIImage`).

/// Decodes the photos of the products for the screens, off the main actor, at the size of their box, and keeps the
/// results in memory.
///
/// - A picture in memory is there at once (`cached(_:pixelSize:)`), so a list that scrolls back shows the photo in its
///   first frame.
/// - The sizes of the boxes go up in steps of `step` pixels, so that boxes of almost the same size use one picture.
/// - The memory has a limit in bytes. When it is full, or when the system needs memory, the loader removes pictures.
///   `removeAll()` removes all of them, for example when the app gets a memory warning.
/// - A task that is cancelled before its decode starts does no decode, for example the task of a row that scrolled
///   away.
/// - A new photo of a product has a new file. `invalidate(productId:keeping:)` removes the pictures of the earlier
///   files of the product, so that their memory is free.
///
/// The loader is safe to use from each thread.
public final class PhotoLoader<Picture: AnyObject & Sendable>: @unchecked Sendable {
    // `NSCache` is safe to use from more than one thread. The other stored values are constants or in a `Mutex`.

    /// Decodes the photo file for a square box of `side` x `side` pixels. The result is the picture and the bytes of
    /// memory that it uses, or nil when the file cannot be decoded.
    public typealias Decode = @Sendable (_ url: URL, _ side: Int) -> (picture: Picture, cost: Int)?

    /// The step of the box sizes, in pixels.
    public static var step: Int { 64 }

    private final class Entry {
        let picture: Picture

        init(_ picture: Picture) {
            self.picture = picture
        }
    }

    private let cache = NSCache<NSString, Entry>()
    private let decode: Decode
    /// The keys in the cache of each product, by the identifier of the product. A key that the cache removed can
    /// stay here: its removal then does nothing.
    private let keys = Mutex<[String: Set<String>]>([:])

    /// - Parameters:
    ///   - costLimit: The bytes of memory for the pictures. See `costLimit(physicalMemory:)`.
    ///   - decode: Decodes a photo file. The loader calls it off the main actor.
    public init(costLimit: Int, decode: @escaping Decode) {
        cache.totalCostLimit = costLimit
        self.decode = decode
    }

    /// The bytes of memory for the pictures on a device with `physicalMemory` bytes: an eighth of the memory that an
    /// app can use, which is about an eighth of the memory of the device. That is one sixty-fourth of the device
    /// memory, from 16 MB to 128 MB. The Android app uses an eighth of the memory of the app.
    public static func costLimit(physicalMemory: UInt64) -> Int {
        let megabyte: UInt64 = 1024 * 1024
        return Int(min(max(physicalMemory / 64, 16 * megabyte), 128 * megabyte))
    }

    /// The side of the picture for a box of `pixelSize` pixels: the next step, from one step to `PhotoFiles.maxEdge`.
    public static func side(for pixelSize: Int) -> Int {
        let steps = (max(pixelSize, 1) + step - 1) / step
        return min(steps * step, PhotoFiles.maxEdge)
    }

    /// The picture of the photo file for a box of `pixelSize` pixels, when it is in memory. It does not read the file.
    public func cached(_ url: URL, pixelSize: Int) -> Picture? {
        cache.object(forKey: Self.key(url, pixelSize: pixelSize))?.picture
    }

    /// The picture of the photo file for a box of `pixelSize` pixels. The decode runs off the main actor. The result is
    /// nil when the file cannot be decoded, or when the task was cancelled before the decode.
    @concurrent
    public func load(_ url: URL, pixelSize: Int) async -> Picture? {
        let key = Self.key(url, pixelSize: pixelSize)
        if let entry = cache.object(forKey: key) {
            return entry.picture
        }
        if Task.isCancelled {
            return nil
        }
        guard let decoded = decode(url, Self.side(for: pixelSize)) else {
            return nil
        }
        // A picture that was decoded stays in memory, also for a task that was cancelled during the decode: the row
        // can come back.
        cache.setObject(Entry(decoded.picture), forKey: key, cost: decoded.cost)
        let product = Self.product(of: url)
        keys.withLock { keys in
            _ = keys[product, default: []].insert(key as String)
        }
        return decoded.picture
    }

    /// Removes the pictures of the files of the product that are not `keeping`: the product got a new photo, its photo
    /// came back with "Undo", or it has no photo now.
    public func invalidate(productId: String, keeping url: URL? = nil) {
        let kept = url.map(\.lastPathComponent)
        let removed = keys.withLock { keys -> Set<String> in
            let all = keys[productId] ?? []
            let stale = all.filter { Self.fileName(ofKey: $0) != kept }
            keys[productId] = all.subtracting(stale)
            return stale
        }
        for key in removed {
            cache.removeObject(forKey: key as NSString)
        }
    }

    /// Removes all pictures from memory.
    public func removeAll() {
        cache.removeAllObjects()
        keys.withLock { $0.removeAll() }
    }

    private static func key(_ url: URL, pixelSize: Int) -> NSString {
        "\(url.lastPathComponent)#\(side(for: pixelSize))" as NSString
    }

    private static func fileName(ofKey key: String) -> String {
        String(key[..<(key.lastIndex(of: "#") ?? key.endIndex)])
    }

    /// The product of a photo file, or an empty text for a file that is not the photo of a product, for example the
    /// prepared photo of an add form.
    private static func product(of url: URL) -> String {
        PhotoFiles.productOf(url.lastPathComponent) ?? ""
    }
}
