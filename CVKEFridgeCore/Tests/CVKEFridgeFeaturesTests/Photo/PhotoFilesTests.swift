import CVKEFridgeFeatures
import Foundation
import Testing

/// The names of the photo files, the files that no product needs, and the sizes of a photo. The Android test
/// `PhotoFilesTest` has the same cases. The case "a name needs an identifier" stops the process on iOS
/// (`precondition`), so this test checks the rule of the identifier through `productOf`.
struct PhotoFilesTests {
    @Test func theNameOfAPhotoHasTheProductAndARandomToken() {
        #expect(PhotoFiles.name(productId: "sample-milk", token: "3f2a-77") == "sample-milk.3f2a-77.jpg")
        #expect(PhotoFiles.productOf("sample-milk.3f2a-77.jpg") == "sample-milk")
        // A temporary file, a removed photo, and other files are not photos.
        for name in [
            "sample-milk.jpg",
            "sample-milk.a.b.jpg",
            "Milk.a.jpg",
            "milk..jpg",
            "milk.a.jpg.tmp",
            "milk.a.jpg.removed",
            "milk.a.png",
            "notes.txt",
        ] {
            #expect(PhotoFiles.productOf(name) == nil, "\(name)")
        }
    }

    @Test func aNameNeedsAnIdentifier() {
        // The parts that `name` refuses are the parts that `productOf` does not read.
        #expect(PhotoFiles.productOf("milk/...x.a.jpg") == nil)
        #expect(PhotoFiles.productOf(String(repeating: "a", count: 65) + ".a.jpg") == nil)
        #expect(PhotoFiles.productOf(String(repeating: "a", count: 64) + ".a.jpg") == String(repeating: "a", count: 64))
        // The token of the store at the start is an identifier: a UUID in small letters.
        let token = UUID().uuidString.lowercased()
        #expect(PhotoFiles.productOf(PhotoFiles.name(productId: "milk", token: token)) == "milk")
    }

    @Test func theNewestFileOfAProductIsItsPhoto() {
        let files = [
            PhotoFile(name: "milk.old.jpg", modified: Date(timeIntervalSince1970: 10)),
            PhotoFile(name: "milk.new.jpg", modified: Date(timeIntervalSince1970: 20)),
            PhotoFile(name: "eggs.a.jpg", modified: Date(timeIntervalSince1970: 5)),
            PhotoFile(name: "eggs.b.jpg.tmp", modified: Date(timeIntervalSince1970: 30)),
        ]
        #expect(PhotoFiles.current(files) == ["milk": "milk.new.jpg", "eggs": "eggs.a.jpg"])
    }

    @Test func theFilesThatNoProductNeedsAreTheOrphans() {
        let names = [
            "milk.new.jpg",
            "milk.old.jpg",
            "eggs.a.jpg",
            "gone.a.jpg",
            "milk.x.jpg.removed",
            "milk.y.jpg.tmp",
            "notes.txt",
        ]
        let current = ["milk": "milk.new.jpg", "eggs": "eggs.a.jpg"]
        #expect(
            PhotoFiles.unwanted(names, current: current, productIds: ["milk", "eggs"])
                == ["milk.old.jpg", "gone.a.jpg", "milk.x.jpg.removed", "milk.y.jpg.tmp", "notes.txt"]
        )
        // A product that is not in the inventory loses its photo.
        #expect(PhotoFiles.unwanted(["milk.new.jpg", "eggs.a.jpg"], current: current, productIds: ["milk"]) == ["eggs.a.jpg"])
    }

    @Test func aLargePictureGetsALongestEdgeOf1024AndKeepsItsShape() {
        #expect(PhotoFiles.targetSize(width: 4000, height: 3000) == (1024, 768))
        #expect(PhotoFiles.targetSize(width: 3000, height: 4000) == (768, 1024))
        #expect(PhotoFiles.targetSize(width: 12_000, height: 10) == (1024, 1))
        // A small picture keeps its size.
        #expect(PhotoFiles.targetSize(width: 800, height: 600) == (800, 600))
    }

    @Test func theSampleSizeKeepsEachEdgeAsLargeAsTheBox() {
        // A thumbnail of 126 px: 1024 x 768 / 4 is 256 x 192. Divided by 8, the short edge is too small.
        #expect(PhotoFiles.sampleSize(width: 1024, height: 768, boxWidth: 126, boxHeight: 126) == 4)
        #expect(PhotoFiles.sampleSize(width: 1024, height: 768, boxWidth: 945, boxHeight: 709) == 1)
        #expect(PhotoFiles.sampleSize(width: 4000, height: 3000, boxWidth: 100, boxHeight: 100) == 16)
        #expect(PhotoFiles.sampleSize(width: 50, height: 50, boxWidth: 100, boxHeight: 100) == 1)
    }

    // Correction of PhotoFiles.kt:96-99: a box with a size of 0, for example a view before its layout, did not stop
    // the loop.
    @Test func aBoxWithNoSizeCountsAsOnePixel() {
        #expect(PhotoFiles.sampleSize(width: 1024, height: 768, boxWidth: 0, boxHeight: 0) == 512)
        #expect(PhotoFiles.sampleSize(width: 1024, height: 768, boxWidth: -5, boxHeight: 1) == 512)
    }
}
