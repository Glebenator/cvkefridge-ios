import CVKEFridgeFeatures
import Foundation
import Testing

/// The files of the photo store in a folder on the computer: save, remove, undo, read again, and clean. The Android
/// test `PhotoStoreTest` has the same cases. The last tests are for the prepared photos and the old files.
struct PhotoStoreTests {
    private struct PictureCannotBeRead: Error {}

    private let folder: ScratchFolder
    private let tokens = LockedBox(0)
    private let clock = LockedBox(Date(timeIntervalSince1970: 2_000_000_000))

    init() throws {
        folder = try ScratchFolder()
    }

    private var directory: URL {
        folder.url.appending(path: "photos", directoryHint: .isDirectory)
    }

    private var preparedDirectory: URL {
        folder.url.appending(path: "photos-prepared", directoryHint: .isDirectory)
    }

    private func store() -> PhotoStore {
        let tokens = tokens
        let clock = clock
        return PhotoStore(
            directory: directory,
            newToken: { "t" + String(tokens.update { $0 += 1; return $0 }) },
            now: { clock.value }
        )
    }

    private func names() -> [String] {
        folder.names(in: directory)
    }

    private func bytes(_ text: String) -> PhotoFileWriter {
        { url in try Data(text.utf8).write(to: url) }
    }

    private func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    @Test func aNewPhotoReplacesTheOldOneAndANewStoreReadsIt() async throws {
        defer { folder.remove() }
        let store = store()
        await store.read()
        let first = try await store.save(productId: "milk", encode: bytes("first"))
        #expect(first.url == directory.appending(path: "milk.t1.jpg"))
        let second = try await store.save(productId: "milk", encode: bytes("second"))
        #expect(names() == ["milk.t2.jpg"])
        #expect(try text(second.url) == "second")
        #expect(await store.photos == ["milk": second])

        // After a restart of the app, a new store finds the photo.
        let again = self.store()
        #expect(await again.photos.isEmpty)
        await again.read()
        #expect(await again.photos == ["milk": second])
    }

    @Test func aWriteThatFailsKeepsThePhotoAndLeavesNoFile() async throws {
        defer { folder.remove() }
        let store = store()
        let photo = try await store.save(productId: "milk", encode: bytes("good"))
        await #expect(throws: PictureCannotBeRead.self) {
            try await store.save(productId: "milk") { _ in throw PictureCannotBeRead() }
        }
        // Also a write that stops after a part of the file.
        await #expect(throws: PictureCannotBeRead.self) {
            try await store.save(productId: "milk") { url in
                try Data("half".utf8).write(to: url)
                throw PictureCannotBeRead()
            }
        }
        #expect(names() == ["milk.t1.jpg"])
        #expect(await store.photos == ["milk": photo])
    }

    @Test func aRemovedPhotoComesBackWithUndoAndTheCleanupDeletesIt() async throws {
        defer { folder.remove() }
        let store = store()
        let photo = try await store.save(productId: "milk", encode: bytes("photo"))
        let removed = try #require(try await store.remove(productId: "milk"))
        #expect(await store.photos.isEmpty)
        #expect(names() == ["milk.t1.jpg.removed"])
        #expect(try await store.remove(productId: "milk") == nil)

        #expect(await store.restore(removed))
        #expect(await store.photos == ["milk": photo])

        // When the message with "Undo" closed, the cleanup deletes the removed file.
        let again = try #require(try await store.remove(productId: "milk"))
        await store.clean(productIds: ["milk"])
        #expect(names().isEmpty)
        #expect(!(await store.restore(again)))
    }

    @Test func anUndoDoesNotReplaceANewerPhoto() async throws {
        defer { folder.remove() }
        let store = store()
        try await store.save(productId: "milk", encode: bytes("old"))
        let removed = try #require(try await store.remove(productId: "milk"))
        let newer = try await store.save(productId: "milk", encode: bytes("new"))
        #expect(!(await store.restore(removed)))
        #expect(await store.photos == ["milk": newer])
    }

    @Test func theCleanupDeletesTheFilesThatNoProductNeeds() async throws {
        defer { folder.remove() }
        let store = store()
        try await store.save(productId: "milk", encode: bytes("milk"))
        try await store.save(productId: "eggs", encode: bytes("eggs"))
        // Files of a write that stopped, of an older photo, and of another program.
        try Data("half".utf8).write(to: directory.appending(path: "milk.t9.jpg.tmp"))
        let old = directory.appending(path: "milk.old.jpg")
        try Data("old".utf8).write(to: old)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: old.path)
        try Data("?".utf8).write(to: directory.appending(path: "notes.txt"))

        // Eggs was deleted from the inventory.
        await store.clean(productIds: ["milk"])
        #expect(names() == ["milk.t1.jpg"])
        #expect(Set(await store.photos.keys) == ["milk"])
    }

    @Test func aPreparedPhotoBecomesThePhotoOfTheNewProduct() async throws {
        defer { folder.remove() }
        let store = store()
        let prepared = try await store.prepare(encode: bytes("from the form"))
        #expect(prepared == PreparedPhoto(fileName: "t1.jpg"))
        #expect(folder.names(in: preparedDirectory) == ["t1.jpg"])
        #expect(try text(try #require(await store.url(of: prepared))) == "from the form")

        let photo = try await store.adopt(productId: "milk", prepared: prepared)
        #expect(try text(photo.url) == "from the form")
        #expect(names() == ["milk.t2.jpg"])
        #expect(folder.names(in: preparedDirectory).isEmpty)
        #expect(await store.photos == ["milk": photo])
    }

    @Test func aPreparedPhotoThatNoProductGetsGoes() async throws {
        defer { folder.remove() }
        let store = store()
        let removed = try await store.prepare(encode: bytes("removed in the form"))
        await store.discard(removed)
        #expect(folder.names(in: preparedDirectory).isEmpty)
        // A write that fails leaves no file.
        await #expect(throws: PictureCannotBeRead.self) {
            try await store.prepare { url in
                try Data("half".utf8).write(to: url)
                throw PictureCannotBeRead()
            }
        }
        #expect(folder.names(in: preparedDirectory).isEmpty)
        // A name that is not in the folder of the prepared photos is not a prepared photo.
        #expect(await store.url(of: PreparedPhoto(fileName: "../photos/milk.t1.jpg")) == nil)
        await #expect(throws: (any Error).self) {
            try await store.adopt(productId: "milk", prepared: PreparedPhoto(fileName: "../x.jpg"))
        }
    }

    @Test func thePreparedPhotosOfFormsThatClosedGoAfterOneDay() async throws {
        defer { folder.remove() }
        let store = store()
        let old = try await store.prepare(encode: bytes("old"))
        let recent = try await store.prepare(encode: bytes("recent"))
        let day = PhotoStore.maxAge
        let now = clock.value
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-day - 1)],
            ofItemAtPath: preparedDirectory.appending(path: old.fileName).path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-day + 60)],
            ofItemAtPath: preparedDirectory.appending(path: recent.fileName).path
        )
        await store.cleanPrepared()
        #expect(folder.names(in: preparedDirectory) == [recent.fileName])
        // The same rule deletes the old files of the camera.
        PhotoStore.deleteFiles(in: preparedDirectory, olderThan: now)
        #expect(folder.names(in: preparedDirectory).isEmpty)
    }
}
