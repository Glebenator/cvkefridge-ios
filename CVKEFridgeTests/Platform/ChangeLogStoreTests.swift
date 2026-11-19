import CVKEFridgeFeatures
import Foundation
import Testing
@testable import CVKEFridge

/// The change log on the disk: the changes of one action are all in the log, or none of them is, also when the write
/// stops in the middle (for example, the battery is empty).
struct ChangeLogStoreTests {
    private let folder: URL
    private let file: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "log-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appending(path: "changes.jsonl")
    }

    private func change(_ id: String, _ body: ChangeBody) -> Change {
        Change(id: id, at: 1_000 + id.count, origin: "phone", body: body)
    }

    private var salt: Product {
        Product(id: "salt", name: "Salt", category: .condiment, unit: .g, barcode: nil, foodId: nil)
    }

    /// The changes of a change of the unit from g to kg: the product, then the batch with its new quantity.
    private var unitChange: [Change] {
        let kg = Product(id: "salt", name: "Salt", category: .condiment, unit: .kg, barcode: nil, foodId: nil)
        return [
            change("c3", .productSaved(product: kg)),
            change("c4", .batchEdited(
                batchId: "b1",
                quantity: 500,
                storageAreaId: "fridge",
                dateAdded: CalendarDate(year: 2026, month: 5, day: 1)!,
                expiry: nil
            )),
        ]
    }

    private var start: [Change] {
        [
            change("c1", .productSaved(product: salt)),
            change("c2", .batchAdded(batch: Batch(
                id: "b1",
                productId: "salt",
                quantity: 500_000,
                storageAreaId: "fridge",
                dateAdded: CalendarDate(year: 2026, month: 5, day: 1)!,
                expiry: nil
            ))),
        ]
    }

    private func clean() {
        try? FileManager.default.removeItem(at: folder)
    }

    @Test func anAppendThatStoppedAfterItsFirstLineIsRemovedAtTheNextStart() async throws {
        defer { clean() }
        let store = ChangeLogStore(file: file)
        try await store.append(start)
        let committed = try Data(contentsOf: file)

        // The first line of the action is on the disk, and the second is not. The app stops here.
        try await store.stopAppend(unitChange, keptLines: 1)
        #expect(try Data(contentsOf: file).count > committed.count)

        // The next start reads the log as it was before the action: the product stays in g.
        let contents = try await ChangeLogStore(file: file).read()
        #expect(contents.changes == start)
        #expect(contents.skippedLines == 0)
        #expect(try Data(contentsOf: file) == committed)
    }

    @Test func anAppendThatStoppedBeforeItsFirstLineChangesNothing() async throws {
        defer { clean() }
        let store = ChangeLogStore(file: file)
        try await store.append(start)
        let committed = try Data(contentsOf: file)

        try await store.stopAppend(unitChange, keptLines: 0)

        let contents = try await ChangeLogStore(file: file).read()
        #expect(contents.changes == start)
        #expect(try Data(contentsOf: file) == committed)
    }

    @Test func anAppendWithAllItsLinesOnTheDiskStaysWhenOnlyTheRecordWasNotRemoved() async throws {
        defer { clean() }
        let store = ChangeLogStore(file: file)
        try await store.append(start)

        // All lines are on the disk. The record of the append was not removed before the app stopped.
        try await store.stopAppend(unitChange, keptLines: 2)

        let contents = try await ChangeLogStore(file: file).read()
        #expect(contents.changes == start + unitChange)
        #expect(contents.skippedLines == 0)
    }

    @Test func theNextAppendAfterAStoppedAppendStartsFromTheCommittedLog() async throws {
        defer { clean() }
        let store = ChangeLogStore(file: file)
        try await store.append(start)
        try await store.stopAppend(unitChange, keptLines: 1)

        let restarted = ChangeLogStore(file: file)
        try await restarted.append(unitChange)

        let contents = try await restarted.read()
        #expect(contents.changes == start + unitChange)
        #expect(contents.skippedLines == 0)
    }

    @Test func aCompleteAppendLeavesNoRecord() async throws {
        defer { clean() }
        let store = ChangeLogStore(file: file)
        try await store.append(start)
        try await store.append(unitChange)

        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(names == ["changes.jsonl"])
        #expect(try await store.read().changes == start + unitChange)
    }

    @Test func anAppendThatFailsAndCannotCutTheLogKeepsItsRecordForTheNextRead() async throws {
        defer { clean() }
        let store = ChangeLogStore(file: file)
        try await store.append(start)
        let committed = try Data(contentsOf: file)

        // The write stops after the first line of the action, and the log cannot be cut back.
        await store.injectFaults(ChangeLogStore.Faults(writeLines: 1, truncate: true))
        await #expect(throws: (any Error).self) { try await store.append(unitChange) }
        #expect(try Data(contentsOf: file).count > committed.count)
        #expect(FileManager.default.fileExists(atPath: file.path + ".append"), "The record of the append went")

        // The next read cuts the log back to its length before the action, and then removes the record.
        let contents = try await store.read()
        #expect(contents.changes == start)
        #expect(contents.skippedLines == 0)
        #expect(try Data(contentsOf: file) == committed)
        #expect(!FileManager.default.fileExists(atPath: file.path + ".append"))
    }

    @Test func anAppendThatFailsAndCutsTheLogLeavesNoRecord() async throws {
        defer { clean() }
        let store = ChangeLogStore(file: file)
        try await store.append(start)
        let committed = try Data(contentsOf: file)

        await store.injectFaults(ChangeLogStore.Faults(writeLines: 1, truncate: false))
        await #expect(throws: (any Error).self) { try await store.append(unitChange) }
        #expect(try Data(contentsOf: file) == committed)
        #expect(!FileManager.default.fileExists(atPath: file.path + ".append"))
        #expect(try await store.read().changes == start)
    }

    @Test func aHalfLineWithNoRecordIsSkippedAsBefore() async throws {
        defer { clean() }
        // A half line of an older version of the app, with no record of the append: the line is not read, and it
        // stays in the file. The next change starts on its own line.
        let text = ChangeCodec.encode(start[0]) + "\n" + String(ChangeCodec.encode(start[1]).prefix(20))
        try Data(text.utf8).write(to: file)
        let store = ChangeLogStore(file: file)

        var contents = try await store.read()
        #expect(contents.changes == [start[0]])
        #expect(contents.skippedLines == 1)

        try await store.append([start[1]])
        contents = try await store.read()
        #expect(contents.changes == start)
        #expect(contents.skippedLines == 1)
    }
}
