import Foundation

/// Why a settings file gave no value.
enum JSONFileStoreError: Error, Equatable, Sendable {
    /// The file is there, but its text is not a value: it is damaged, or a different program wrote it.
    case damaged
    /// The file is there, but the app cannot read it now.
    case unreadable
}

/// One small settings file, as JSON. It takes the place of a DataStore file of the Android app.
///
/// A write makes a new file and then puts it in the place of the old file, so a write that stops in the middle leaves
/// the old file. The store is an actor: one read or write runs at a time, and not on the main actor.
///
/// The store does not decide what a file that it cannot read means. `read()` throws, and the owner of the settings
/// decides: the recent foods start again with the default value, and the reminder settings change nothing.
///
/// ```swift
/// let recent = JSONFileStore(file: folders.recent, defaultValue: RecentSettings(),
///                            decode: RecentSettings.decode, encode: { try $0.encoded() })
/// ```
actor JSONFileStore<Value: Sendable> {
    private let file: URL
    private let defaultValue: Value
    private let decode: @Sendable (Data) throws -> Value
    private let encode: @Sendable (Value) throws -> Data

    /// - Parameters:
    ///   - file: The file of the settings. A write makes it and its folder when they are not there.
    ///   - defaultValue: The value of a file that is not there.
    ///   - decode: Gives the value of the bytes of the file, or throws when they are not a value.
    ///   - encode: Gives the bytes of a value.
    init(
        file: URL,
        defaultValue: Value,
        decode: @escaping @Sendable (Data) throws -> Value,
        encode: @escaping @Sendable (Value) throws -> Data
    ) {
        self.file = file
        self.defaultValue = defaultValue
        self.decode = decode
        self.encode = encode
    }

    /// The value of the file. A file that is not there gives the default value.
    ///
    /// - Throws: `JSONFileStoreError.damaged` when the text of the file is not a value, and
    ///   `JSONFileStoreError.unreadable` when the file cannot be read.
    func read() throws(JSONFileStoreError) -> Value {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return defaultValue
        } catch {
            throw .unreadable
        }
        do {
            return try decode(data)
        } catch {
            throw .damaged
        }
    }

    /// Replaces the file with the value.
    ///
    /// - Throws: An error when the value cannot be encoded or the file cannot be written.
    func write(_ value: Value) throws {
        let data = try encode(value)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }
}
