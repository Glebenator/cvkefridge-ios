import Foundation

// The photos of the products. The Android file `app/src/main/java/com/cvke/fridge/photo/PhotoStore.kt` in
// cvkefridge-android has the same file rules. The deletion of old camera files of
// `app/src/main/java/com/cvke/fridge/photo/CameraCaptures.kt` is `PhotoStore.deleteFiles(in:olderThan:)`.

/// Writes the JPEG of a photo into a file. The app implements it with ImageIO: it decodes the picture at the size of
/// `PhotoFiles.targetSize`, turns it as its orientation says, and writes a JPEG with no metadata.
///
/// - Parameter url: The new file. The closure makes it.
/// - Throws: Each error of the decode or the write. The store then keeps the photo that the product had.
public typealias PhotoFileWriter = @Sendable (_ url: URL) throws -> Void

/// The photos of the products: one JPEG file for each product in a `directory` of the files of the app (see
/// `PhotoFiles`). The folder is not in the backup, so the photos stay on the phone. The store keeps no reference to
/// the picture that the person selected: `save` writes a copy, and the copy is the photo.
///
/// The add form can have a photo before the product exists. `prepare` writes such a photo into `preparedDirectory`,
/// and `adopt` makes it the photo of the product after the save.
///
/// The store is an actor: one change runs at a time, and the file operations are not on the main actor. It writes no
/// names or pictures to a log.
public actor PhotoStore {
    /// The age after which a prepared photo or a camera file is old: one day.
    public static let maxAge: TimeInterval = 24 * 60 * 60

    private let directory: URL
    private let preparedDirectory: URL
    private let newToken: @Sendable () -> String
    private let now: @Sendable () -> Date
    private var didRead = false

    /// The photo of each product that has one, by the identifier of the product. It is empty before `read()`.
    public private(set) var photos: [String: ProductPhoto] = [:]

    /// - Parameters:
    ///   - directory: The folder of the photos, for example `photos` in Application Support.
    ///   - preparedDirectory: The folder of the prepared photos. Nil gives the folder `<directory>-prepared` next to
    ///     `directory`.
    ///   - newToken: Makes the random part of the name of a new photo: an identifier of 1 to 64 of the characters a
    ///     to z, 0 to 9, and "-".
    ///   - now: The instant of now.
    public init(
        directory: URL,
        preparedDirectory: URL? = nil,
        newToken: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directory = directory
        self.preparedDirectory = preparedDirectory
            ?? directory.deletingLastPathComponent()
            .appending(path: directory.lastPathComponent + "-prepared", directoryHint: .isDirectory)
        self.newToken = newToken
        self.now = now
    }

    /// Reads the folder, one time.
    public func read() {
        readOnce()
    }

    /// Writes a new photo of the product, and deletes the photo that it had. `encode` writes the JPEG. A write that
    /// fails leaves the photo that the product had, and no file.
    ///
    /// - Throws: Each error of the folder, of the rename, and of `encode`.
    @discardableResult
    public func save(productId: String, encode: PhotoFileWriter) throws -> ProductPhoto {
        readOnce()
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = PhotoFiles.name(productId: productId, token: newToken())
        let target = fileURL(name)
        let temporary = fileURL(name + PhotoFiles.temporary)
        defer { try? fileManager.removeItem(at: temporary) }
        try encode(temporary)
        try fileManager.moveItem(at: temporary, to: target)
        Self.excludeFromBackup(target)
        if let old = photos[productId] {
            try? fileManager.removeItem(at: old.url)
        }
        let photo = ProductPhoto(url: target)
        photos[productId] = photo
        return photo
    }

    /// Writes a new photo of the product from the bytes of a JPEG.
    @discardableResult
    public func save(productId: String, jpeg: Data) throws -> ProductPhoto {
        try save(productId: productId) { url in
            try jpeg.write(to: url)
        }
    }

    /// Removes the photo of the product. The file stays as a removed photo, so that `restore` can bring it back, until
    /// `clean` deletes it. The result is nil when the product has no photo.
    ///
    /// - Throws: An error when the file cannot be renamed.
    public func remove(productId: String) throws -> RemovedPhoto? {
        readOnce()
        guard let photo = photos[productId] else {
            return nil
        }
        let removedName = photo.url.lastPathComponent + PhotoFiles.removed
        try FileManager.default.moveItem(at: photo.url, to: fileURL(removedName))
        photos[productId] = nil
        return RemovedPhoto(productId: productId, fileName: removedName)
    }

    /// Brings back a removed photo. A product that got a new photo after the remove keeps the new photo. The result
    /// is true when the photo came back.
    public func restore(_ removed: RemovedPhoto) -> Bool {
        readOnce()
        guard photos[removed.productId] == nil,
              removed.fileName.hasSuffix(PhotoFiles.removed),
              !removed.fileName.contains("/")
        else {
            return false
        }
        let name = String(removed.fileName.dropLast(PhotoFiles.removed.count))
        guard PhotoFiles.productOf(name) == removed.productId else {
            return false
        }
        let target = fileURL(name)
        do {
            try FileManager.default.moveItem(at: fileURL(removed.fileName), to: target)
        } catch {
            return false
        }
        photos[removed.productId] = ProductPhoto(url: target)
        return true
    }

    /// Deletes each file that no product needs: the photos of the products that are not in `productIds`, the removed
    /// photos, the files of a write that stopped, and the older photos of a product. Call it only when no message with
    /// "Undo" can bring back a product or a photo.
    public func clean(productIds: Set<String>) {
        readOnce()
        let kept = photos.filter { productIds.contains($0.key) }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let current = kept.mapValues(\.url.lastPathComponent)
        for name in PhotoFiles.unwanted(names, current: current, productIds: productIds) {
            try? FileManager.default.removeItem(at: fileURL(name))
        }
        photos = kept
    }

    /// Writes a photo for a product that does not exist yet: the photo of the add form. `encode` writes the JPEG.
    ///
    /// - Throws: Each error of the folder and of `encode`. Then no file stays.
    public func prepare(encode: PhotoFileWriter) throws -> PreparedPhoto {
        try FileManager.default.createDirectory(at: preparedDirectory, withIntermediateDirectories: true)
        let name = newToken() + PhotoFiles.fileExtension
        let target = preparedDirectory.appending(path: name, directoryHint: .notDirectory)
        do {
            try encode(target)
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
        Self.excludeFromBackup(target)
        return PreparedPhoto(fileName: name)
    }

    /// The file of a prepared photo, to show it in the add form. Nil when the name is not a name in the folder of the
    /// prepared photos.
    public func url(of prepared: PreparedPhoto) -> URL? {
        preparedFile(prepared)
    }

    /// Makes a prepared photo the photo of the product, and deletes the prepared file.
    ///
    /// - Throws: An error when the prepared file cannot be read or the photo cannot be written.
    @discardableResult
    public func adopt(productId: String, prepared: PreparedPhoto) throws -> ProductPhoto {
        guard let file = preparedFile(prepared) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let photo = try save(productId: productId) { url in
            try FileManager.default.copyItem(at: file, to: url)
        }
        discard(prepared)
        return photo
    }

    /// Deletes a prepared photo that no product got, for example after "Remove" in the add form.
    public func discard(_ prepared: PreparedPhoto) {
        if let file = preparedFile(prepared) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Deletes the prepared photos that are older than one day: the photos of forms that closed with no save.
    public func cleanPrepared() {
        Self.deleteFiles(in: preparedDirectory, olderThan: now().addingTimeInterval(-Self.maxAge))
    }

    /// Deletes the files in a folder that changed last before `limit`. The app also uses it for the files of the
    /// camera that did not come back, with the limit of one day (`maxAge`).
    public static func deleteFiles(in folder: URL, olderThan limit: Date) {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else {
            return
        }
        for name in names {
            let file = folder.appending(path: name, directoryHint: .notDirectory)
            guard let modified = (try? fileManager.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date,
                  modified < limit
            else {
                continue
            }
            try? fileManager.removeItem(at: file)
        }
    }

    /// The file of a prepared photo, only when its name is a plain name in the folder of the prepared photos.
    private func preparedFile(_ prepared: PreparedPhoto) -> URL? {
        let name = prepared.fileName
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else {
            return nil
        }
        return preparedDirectory.appending(path: name, directoryHint: .notDirectory)
    }

    private func fileURL(_ name: String) -> URL {
        directory.appending(path: name, directoryHint: .notDirectory)
    }

    private func readOnce() {
        if didRead {
            return
        }
        let fileManager = FileManager.default
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        let files = names.map { name in
            let modified = (try? fileManager.attributesOfItem(atPath: fileURL(name).path))?[.modificationDate] as? Date
            return PhotoFile(name: name, modified: modified ?? .distantPast)
        }
        photos = PhotoFiles.current(files).mapValues { ProductPhoto(url: fileURL($0)) }
        didRead = true
    }

    private static func excludeFromBackup(_ file: URL) {
        #if canImport(Darwin)
        var url = file
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        #endif
    }
}
