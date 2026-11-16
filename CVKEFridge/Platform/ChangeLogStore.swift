import CVKEFridgeFeatures
import Foundation

/// The change log on the phone: one file with one change on each line, as JSON from `ChangeCodec`. The inventory is
/// the replay of this log.
///
/// The Android file `data/ChangeLogStore.kt` has the same file format. Three things are different here:
///
/// - A line that cannot be decoded does not stop the app. `read()` gives the changes of the other lines and the number
///   of the lines that it did not read. The lines stay in the file, so that a later version of the app can read them.
/// - `append(_:)` writes only the new lines at the end of the file, in one write, and waits until they are on the
///   disk. It does not write the whole file again.
/// - The changes of one action are all in the log, or none of them is. Before an append, the store writes a small
///   record next to the log (`<log>.append`): the length of the log before the append and after it. The record goes
///   after the append. When the phone stops during an append, for example with an empty battery, the record is still
///   there at the next start. If the new lines are not all on the disk, `read()` then cuts the log back to its length
///   before the append. So a change of the unit never gives the new unit of the product with the old quantities of
///   the batches. The record is in the folder of the log, which is not in the backup.
///
/// A half line with no record (from an older version of the app) is a line that cannot be decoded, as before.
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
    /// The record of the append that runs: two numbers on one line, the length of the log in bytes before the append
    /// and after it.
    private let record: URL

    /// - Parameter file: The file of the log. `append(_:)` makes it and its folder when they are not there.
    init(file: URL) {
        self.file = file
        record = file.deletingLastPathComponent()
            .appending(path: file.lastPathComponent + ".append", directoryHint: .notDirectory)
    }

    /// All changes, in the order of the file. A log that does not exist is empty. The lines of an append that did not
    /// complete are removed first.
    ///
    /// - Throws: An error when the file is there but cannot be read, or when the lines of an append that did not
    ///   complete cannot be removed.
    func read() throws -> Contents {
        try recover()
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return Contents(changes: [], skippedLines: 0)
        }
        var contents = Contents(changes: [], skippedLines: 0)
        for line in Self.lines(of: data) {
            switch Self.decode(line) {
            case .change(let change):
                contents.changes.append(change)
            case .notAChange:
                contents.skippedLines += 1
            case .empty:
                break
            }
        }
        return contents
    }

    /// Adds the changes to the end of the log. The call returns after the new lines are on the disk. A write that
    /// fails leaves the log as it was. When the app stops during the write, the next `read()` removes the lines of
    /// the write.
    ///
    /// - Throws: An error when the file cannot be made or written.
    func append(_ changes: [Change]) throws {
        if changes.isEmpty {
            return
        }
        try recover()
        let handle = try openForAppend()
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        let data = try lines(of: changes, after: end, in: handle)
        try writeRecord(committed: end, expected: end + UInt64(data.count))
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            // No half line stays in the log.
            try? handle.truncate(atOffset: end)
            try? handle.synchronize()
            try? FileManager.default.removeItem(at: record)
            throw error
        }
        // The lines are on the disk. A record that stays is no problem: the next read finds all the lines.
        try? FileManager.default.removeItem(at: record)
    }

    /// Replaces the log with the changes: the app writes a new file and then puts it in the place of the old file. An
    /// empty list removes the log. Only the debug build and the tests replace the log.
    ///
    /// - Throws: An error when the file cannot be written or removed.
    func replace(_ changes: [Change]) throws {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: record)
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
        try? FileManager.default.removeItem(at: record)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file, options: .atomic)
    }

    #if DEBUG
    /// Debug build only, for the tests: an append that stops as when the phone turns off in the middle of the write.
    /// The record of the append and the first `keptLines` lines of the changes go on the disk, and the store then does
    /// nothing more.
    func stopAppend(_ changes: [Change], keptLines: Int) throws {
        let handle = try openForAppend()
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        let data = try lines(of: changes, after: end, in: handle)
        try writeRecord(committed: end, expected: end + UInt64(data.count))
        let kept = changes.prefix(keptLines).map { ChangeCodec.encode($0) + "\n" }.joined()
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(kept.utf8))
        try handle.synchronize()
    }
    #endif

    // MARK: The record of an append

    /// Removes the lines of an append that did not complete, and then the record. With no record, it does nothing.
    ///
    /// The append completed when the log has its length after the append, and each line of the append is a change.
    /// The log then stays as it is. Else the log goes back to its length before the append.
    private func recover() throws {
        let fileManager = FileManager.default
        guard let text = try? String(contentsOf: record, encoding: .utf8) else {
            return
        }
        let numbers = text.split(whereSeparator: \.isWhitespace).compactMap { UInt64($0) }
        guard numbers.count == 2, numbers[0] <= numbers[1], fileManager.fileExists(atPath: file.path) else {
            // A record that cannot be read tells nothing. The lines of the log stay.
            try? fileManager.removeItem(at: record)
            return
        }
        let committed = numbers[0]
        let expected = numbers[1]
        let handle = try FileHandle(forUpdating: file)
        defer { try? handle.close() }
        let length = try handle.seekToEnd()
        if length < committed {
            // The log is shorter than before the append, so the record is not of this log. The lines stay.
            try? fileManager.removeItem(at: record)
            return
        }
        if try !appendIsComplete(handle, committed: committed, expected: expected, length: length) {
            try handle.truncate(atOffset: committed)
            try handle.synchronize()
        }
        try fileManager.removeItem(at: record)
    }

    /// True when the log has all the lines of the append, and nothing after them.
    private func appendIsComplete(_ handle: FileHandle, committed: UInt64, expected: UInt64, length: UInt64) throws -> Bool {
        guard length == expected else {
            return false
        }
        try handle.seek(toOffset: committed)
        let data = try handle.readToEnd() ?? Data()
        guard UInt64(data.count) == expected - committed, data.last == Self.lineFeed else {
            return false
        }
        // The first line can be the line end after a half line of an older version. It is empty.
        return Self.lines(of: data).allSatisfy { line in
            if case .notAChange = Self.decode(line) {
                return false
            }
            return true
        }
    }

    /// Writes the record of an append and waits until it is on the disk.
    private func writeRecord(committed: UInt64, expected: UInt64) throws {
        guard FileManager.default.createFile(atPath: record.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: record)
        defer { try? handle.close() }
        try handle.write(contentsOf: Data("\(committed) \(expected)\n".utf8))
        try handle.synchronize()
        // The name of the new file is in the folder. The folder also goes on the disk before the append.
        if let folder = FileHandle(forReadingAtPath: record.deletingLastPathComponent().path) {
            try? folder.synchronize()
            try? folder.close()
        }
    }

    // MARK: Lines

    /// The log, open for an append. The call makes the file and its folder when they are not there.
    private func openForAppend() throws -> FileHandle {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: file.path) {
            try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fileManager.createFile(atPath: file.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        return try FileHandle(forUpdating: file)
    }

    /// The bytes of the lines of the changes, for the end of a log with the length `end`.
    private func lines(of changes: [Change], after end: UInt64, in handle: FileHandle) throws -> Data {
        var data = Data()
        if end > 0 {
            // A line that a stopped write of an older version did not complete has no line end. The new change
            // starts on its own line.
            try handle.seek(toOffset: end - 1)
            if try handle.read(upToCount: 1) != Data([Self.lineFeed]) {
                data.append(Self.lineFeed)
            }
        }
        for change in changes {
            data.append(Data(ChangeCodec.encode(change).utf8))
            data.append(Self.lineFeed)
        }
        return data
    }

    /// What one line of the log is.
    private enum Line {
        case change(Change)
        /// The line is not UTF-8, or it is not a change of `ChangeCodec`.
        case notAChange
        /// The line has only spaces.
        case empty
    }

    private static func lines(of data: Data) -> [Data.SubSequence] {
        data.split(separator: lineFeed, omittingEmptySubsequences: true)
    }

    private static func decode(_ line: Data.SubSequence) -> Line {
        var bytes = line
        if bytes.last == carriageReturn {
            bytes = bytes.dropLast()
        }
        guard let text = String(data: Data(bytes), encoding: .utf8) else {
            return .notAChange
        }
        if text.allSatisfy(\.isWhitespace) {
            return .empty
        }
        if let change = try? ChangeCodec.decode(text) {
            return .change(change)
        }
        return .notAChange
    }
}
