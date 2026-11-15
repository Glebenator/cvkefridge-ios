import CVKEFridgeFeatures
import Foundation
import Testing
@testable import CVKEFridge

/// The Undo of the system (a shake of the phone) for a message with "Undo". The simulator cannot shake from a test,
/// so the tests use the undo manager as the system does. The undo manager does not keep its targets, so each test
/// keeps them until its end, as the view of a message does.
@MainActor
struct NoticeUndoTests {
    /// The text of a text field.
    private final class Typing {
        var text = ""
    }

    /// Shows a message with "Undo", registers it as `NoticeView` does, and gives the message and its count of undos.
    private func show(_ text: String, on model: FridgeModel, undoManager: UndoManager, target: UndoTarget) -> (Notice, () -> Int) {
        var undone = 0
        model.showNotice(text, kind: .done, action: .undo) { undone += 1 }
        let notice = model.notice!
        NoticeUndo.register(notice, model: model, undoManager: undoManager, target: target)
        return (notice, { undone })
    }

    private func undoManager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }

    @Test func aShakeUndoesTheMessageAndClosesIt() throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let manager = undoManager()

        let target = UndoTarget()

        manager.beginUndoGrouping()
        let (_, undone) = show("Bread used", on: fixture.model, undoManager: manager, target: target)
        manager.endUndoGrouping()
        #expect(manager.canUndo)
        #expect(manager.undoActionName == "Bread used")

        manager.undo()
        #expect(undone() == 1)
        #expect(fixture.model.notice == nil)
        withExtendedLifetime(target) {}
    }

    @Test func onlyTheMessageOnTheScreenIsOffered() throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let manager = undoManager()
        let first = UndoTarget()
        let second = UndoTarget()

        manager.beginUndoGrouping()
        let (_, firstUndone) = show("Bread used", on: fixture.model, undoManager: manager, target: first)
        manager.endUndoGrouping()
        manager.beginUndoGrouping()
        let (_, secondUndone) = show("Milk used", on: fixture.model, undoManager: manager, target: second)
        manager.endUndoGrouping()
        // The first message went from the screen: its view removes its action.
        manager.removeAllActions(withTarget: first)

        #expect(manager.undoActionName == "Milk used")
        manager.undo()
        #expect(secondUndone() == 1)
        #expect(firstUndone() == 0)
        #expect(!manager.canUndo)
        withExtendedLifetime((first, second)) {}
    }

    @Test func aReplacedMessageDoesNothingAlsoWhenItsActionIsStillRegistered() throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let manager = undoManager()

        let target = UndoTarget()

        manager.beginUndoGrouping()
        let (_, firstUndone) = show("Bread used", on: fixture.model, undoManager: manager, target: target)
        manager.endUndoGrouping()
        // A message with no button replaces it before its view went.
        fixture.model.showNotice("Reminders are on", kind: .information)

        manager.undo()
        #expect(firstUndone() == 0)
        #expect(fixture.model.notice?.text == .custom("Reminders are on", .information))
        withExtendedLifetime(target) {}
    }

    @Test func textTypedAfterTheMessageIsUndoneFirst() throws {
        let fixture = try ModelFixture()
        defer { fixture.removeFolder() }
        let manager = undoManager()
        let typing = Typing()
        let target = UndoTarget()

        manager.beginUndoGrouping()
        let (_, undone) = show("Bread used", on: fixture.model, undoManager: manager, target: target)
        manager.endUndoGrouping()
        // A text field registers its typing with the same undo manager.
        manager.beginUndoGrouping()
        typing.text = "Plum"
        manager.registerUndo(withTarget: typing) { typing in typing.text = "" }
        manager.endUndoGrouping()

        manager.undo()
        #expect(typing.text.isEmpty)
        #expect(undone() == 0)
        #expect(fixture.model.notice != nil)

        manager.undo()
        #expect(undone() == 1)
        withExtendedLifetime((target, typing)) {}
    }
}
