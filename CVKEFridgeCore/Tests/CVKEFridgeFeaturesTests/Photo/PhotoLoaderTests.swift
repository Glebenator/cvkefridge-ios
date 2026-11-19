import CVKEFridgeFeatures
import Foundation
import Testing

/// The pictures of the photos in memory: one decode for each file and size step, the picture at once after the first
/// load, no decode for a cancelled task, and the removal of the pictures of an earlier photo.
struct PhotoLoaderTests {
    /// A picture of the test: the file and the side of the decode.
    private final class Picture: Sendable {
        let file: String
        let side: Int

        init(file: String, side: Int) {
            self.file = file
            self.side = side
        }
    }

    private let decodes = LockedBox<[String]>([])

    private func loader(costLimit: Int = 1_000_000, failing: Set<String> = []) -> PhotoLoader<Picture> {
        let decodes = decodes
        return PhotoLoader(costLimit: costLimit) { url, side in
            decodes.update { $0.append("\(url.lastPathComponent)@\(side)") }
            if failing.contains(url.lastPathComponent) {
                return nil
            }
            return (Picture(file: url.lastPathComponent, side: side), cost: side * side * 4)
        }
    }

    private func photo(_ name: String) -> URL {
        URL(filePath: "/photos/\(name)")
    }

    @Test func theSizesOfTheBoxesGoUpInSteps() {
        #expect(PhotoLoader<Picture>.side(for: 0) == 64)
        #expect(PhotoLoader<Picture>.side(for: 1) == 64)
        #expect(PhotoLoader<Picture>.side(for: 64) == 64)
        #expect(PhotoLoader<Picture>.side(for: 65) == 128)
        #expect(PhotoLoader<Picture>.side(for: 168) == 192)
        #expect(PhotoLoader<Picture>.side(for: 5000) == PhotoFiles.maxEdge)
    }

    @Test func theMemoryLimitIsASixtyFourthOfTheDeviceFrom16To128Megabytes() {
        let megabyte = 1024 * 1024
        let gigabyte: UInt64 = 1024 * 1024 * 1024
        #expect(PhotoLoader<Picture>.costLimit(physicalMemory: 6 * gigabyte) == 96 * megabyte)
        #expect(PhotoLoader<Picture>.costLimit(physicalMemory: 512 * 1024 * 1024) == 16 * megabyte)
        #expect(PhotoLoader<Picture>.costLimit(physicalMemory: 16 * gigabyte) == 128 * megabyte)
    }

    @Test func aPictureIsDecodedOneTimeAndThenIsThereAtOnce() async {
        let loader = loader()
        let milk = photo("milk.t1.jpg")
        #expect(loader.cached(milk, pixelSize: 120) == nil)

        let first = await loader.load(milk, pixelSize: 120)
        #expect(first?.side == 128)
        // A box of almost the same size uses the same picture, with no new decode and with no wait.
        #expect(loader.cached(milk, pixelSize: 100) === first)
        #expect(await loader.load(milk, pixelSize: 110) === first)
        #expect(decodes.value == ["milk.t1.jpg@128"])

        // A larger box gets a larger picture.
        let large = await loader.load(milk, pixelSize: 300)
        #expect(large?.side == 320)
        #expect(decodes.value == ["milk.t1.jpg@128", "milk.t1.jpg@320"])
    }

    @Test func aFileThatCannotBeDecodedGivesNoPicture() async {
        let loader = loader(failing: ["milk.t1.jpg"])
        #expect(await loader.load(photo("milk.t1.jpg"), pixelSize: 120) == nil)
        #expect(loader.cached(photo("milk.t1.jpg"), pixelSize: 120) == nil)
    }

    @Test func aCancelledTaskDoesNoDecode() async {
        let loader = loader()
        let milk = photo("milk.t1.jpg")
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await loader.load(milk, pixelSize: 120)
        }
        #expect(await task.value == nil)
        #expect(decodes.value.isEmpty)

        // A picture in memory is there also for a cancelled task.
        let picture = await loader.load(milk, pixelSize: 120)
        let again = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await loader.load(milk, pixelSize: 120)
        }
        #expect(await again.value === picture)
    }

    @Test func aNewPhotoRemovesThePicturesOfTheEarlierPhoto() async {
        let loader = loader()
        let first = photo("milk.t1.jpg")
        let second = photo("milk.t2.jpg")
        let butter = photo("butter.t1.jpg")
        _ = await loader.load(first, pixelSize: 120)
        _ = await loader.load(first, pixelSize: 300)
        _ = await loader.load(second, pixelSize: 120)
        _ = await loader.load(butter, pixelSize: 120)

        loader.invalidate(productId: "milk", keeping: second)
        #expect(loader.cached(first, pixelSize: 120) == nil)
        #expect(loader.cached(first, pixelSize: 300) == nil)
        #expect(loader.cached(second, pixelSize: 120) != nil)
        // The pictures of the other products stay.
        #expect(loader.cached(butter, pixelSize: 120) != nil)

        // A removed photo: no picture of the product stays.
        loader.invalidate(productId: "milk")
        #expect(loader.cached(second, pixelSize: 120) == nil)
        #expect(loader.cached(butter, pixelSize: 120) != nil)
    }

    @Test func removeAllEmptiesTheMemory() async {
        let loader = loader()
        let milk = photo("milk.t1.jpg")
        _ = await loader.load(milk, pixelSize: 120)
        loader.removeAll()
        #expect(loader.cached(milk, pixelSize: 120) == nil)
        _ = await loader.load(milk, pixelSize: 120)
        #expect(decodes.value.count == 2)
    }

    @Test func theMemoryLimitRemovesPictures() async {
        // Room for one picture of 128 x 128 pixels.
        let loader = loader(costLimit: 128 * 128 * 4)
        let milk = photo("milk.t1.jpg")
        let butter = photo("butter.t1.jpg")
        _ = await loader.load(milk, pixelSize: 128)
        _ = await loader.load(butter, pixelSize: 128)
        #expect(loader.cached(butter, pixelSize: 128) != nil || loader.cached(milk, pixelSize: 128) != nil)
        #expect(loader.cached(butter, pixelSize: 128) == nil || loader.cached(milk, pixelSize: 128) == nil)
    }
}
