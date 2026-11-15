import CVKEFridgeFeatures
import Foundation

/// The change log on the phone: one file with one change on each line, as JSON from `ChangeCodec`. The inventory is
/// the replay of this log.
///
/// The Android file `data/ChangeLogStore.kt` has the same file format. Two things are different here:
///
/// - A line that cannot be decoded does not stop the app. `read()` gives the changes of the other lines and the number
///   of the lines that it did not read. The lines stay in the file, so that a later version of the app can read them.
/// - `append(_:)` writes only the new lines at the end of the file, and waits until they are on the disk. It does not
///   write the whole file again.
///
/// The store is an actor: one read or write runs at a time, and not on the main actor. It writes nothing to a log.
actor ChangeLogStore {
    /// What `read()` gives. `skippedLines` is the number of lines that are not a change.
    struct Contents: Equatable, Sendable {
        var changes: [Change]
        var skippedLines: Int
    }

    private static let lineFeed: UInt8 = 0x0A
    private static let carriageReturn: UInt8 = 0x0D

    private let file: URL

    /// - Parameter file: The file of the log. `append(_:)` makes it and its folder when they are not there.
    init(file: URL) {
        self.file = file
    }

    /// All changes, in the order of the file. A log that does not exist is empty.
    ///
    /// - Throws: An error when the file is there but cannot be read.
    func read() throws -> Contents {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return Contents(changes: [], skippedLines: 0)
        }
        var contents = Contents(changes: [], skippedLines: 0)
        for line in data.split(separator: Self.lineFeed, omittingEmptySubsequences: true) {
            var bytes = line
            if bytes.last == Self.carriageReturn {
                bytes = bytes.dropLast()
            }
            guard let text = String(data: Data(bytes), encoding: .utf8) else {
                contents.skippedLines += 1
                continue
            }
            if text.allSatisfy(\.isWhitespace) {
                continue
            }
            if let change = try? ChangeCodec.decode(text) {
                contents.changes.append(change)
            } else {
                contents.skippedLines += 1
            }
        }
        return contents
    }

    /// Adds the changes to the end of the log. The call returns after the new lines are on the disk. A write that
    /// fails leaves the log as it was.
    ///
    /// - Throws: An error when the file cannot be made or written.
    func append(_ changes: [Change]) throws {
        if changes.isEmpty {
            return
        }
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: file.path) {
            try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fileManager.createFile(atPath: file.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        let handle = try FileHandle(forUpdating: file)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        var data = Data()
        if end > 0 {
            // A line that a stopped write did not complete has no line end. The new change starts on its own line.
            try handle.seek(toOffset: end - 1)
            if try handle.read(upToCount: 1) != Data([Self.lineFeed]) {
                data.append(Self.lineFeed)
            }
        }
        for change in changes {
            data.append(Data(ChangeCodec.encode(change).utf8))
            data.append(Self.lineFeed)
        }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            // No half line stays in the log.
            try? handle.truncate(atOffset: end)
            throw error
        }
    }

    /// Replaces the log with the changes: the app writes a new file and then puts it in the place of the old file. An
    /// empty list removes the log. Only the debug build and the tests replace the log.
    ///
    /// - Throws: An error when the file cannot be written or removed.
    func replace(_ changes: [Change]) throws {
        let fileManager = FileManager.default
        if changes.isEmpty {
            if fileManager.fileExists(atPath: file.path) {
                try fileManager.removeItem(at: file)
            }
            return
        }
        try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let text = changes.map { ChangeCodec.encode($0) + "\n" }.joined()
        try Data(text.utf8).write(to: file, options: .atomic)
    }

    /// Replaces the log with a text that already has one change on each line. Only the tests use it, to start the app
    /// with a log that has lines which are not a change.
    ///
    /// - Throws: An error when the file cannot be written.
    func replace(text: String) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file, options: .atomic)
    }
}
