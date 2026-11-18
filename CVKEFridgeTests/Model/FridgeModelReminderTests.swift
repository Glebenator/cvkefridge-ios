import CVKEFridgeFeatures
import Foundation
import Testing
@testable import CVKEFridge

/// The plan of the reminders after a change of the inventory: it runs in the queue of the reminder planner, not in the
/// queue of the inventory. The fixture clock stays at 12:00 of 1 May 2026.
@MainActor
struct FridgeModelReminderTests {
    private static func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private static func change(_ number: Int, _ body: ChangeBody) -> Change {
        Change(id: "c\(number)", at: number, origin: "other", body: body)
    }

    /// Rice with one batch that expires on 4 May.
    private static let rice: [Change] = [
        change(1, .productSaved(product: Product(id: "rice", name: "Rice", category: .other, unit: .g, barcode: nil, foodId: nil))),
        change(2, .batchAdded(batch: Batch(
            id: "a",
            productId: "rice",
            quantity: 300_000,
            storageAreaId: "fridge",
            dateAdded: date("2026-04-01"),
            expiry: ExpiryDate(date: date("2026-05-04"), source: .printed)
        ))),
    ]

    private static func milk(expires: String) -> InventoryAction {
        .addFood(InventoryAction.AddFood(
            productId: nil,
            name: "Milk",
            category: .dairy,
            unit: .l,
            foodId: nil,
            quantity: 1_000,
            storageAreaId: "fridge",
            expiry: ExpiryDate(date: date(expires), source: .printed)
        ))
    }

    /// The plan for the inventory and the settings of the model now.
    private func expectedPlan(_ model: FridgeModel) -> [PlannedReminder]? {
        guard let inventory = model.content?.inventory, let settings = model.reminders.settings else {
            return nil
        }
        let clock = DayClock(fixed: Self.date("2026-05-01"))
        return ReminderPlan.reminders(inventory: inventory, settings: settings, now: clock.now(), timeZone: clock.timeZone())
    }

    @Test func aWriteDoesNotWaitForTheNotificationCenter() async throws {
        let reminders = RecordingReminders()
        let fixture = try ModelFixture(changes: Self.rice, reminders: reminders, reminderSettings: ReminderSettings(enabled: true))
        defer { fixture.removeFolder() }
        let model = fixture.model
        // The notification center does not answer.
        await reminders.holdUpdates()
        model.start()
        #expect(await eventually { model.content != nil })
        #expect(await eventually { await reminders.waitingUpdates == 1 })

        // The form gets the result of its save, and the next write runs, while the plan waits.
        model.perform(Self.milk(expires: "2026-05-10"), formToken: "form")
        #expect(await eventually { model.formWrite("form") == .saved })
        model.perform(Self.milk(expires: "2026-05-20"))
        #expect(await eventually { model.content?.inventory.batches.count == 3 })
        #expect(await reminders.waitingUpdates == 1)

        // The plans of the two writes are one plan, with the newest inventory. It runs after the plan that waited.
        await reminders.releaseUpdates()
        let expected = try #require(expectedPlan(model))
        #expect(await eventually { await reminders.updates.count == 2 })
        #expect(await reminders.updates.last == expected)
        // The plan has the milk of the second write.
        #expect(expected.contains { reminder in reminder.foods.contains { $0.name == "Milk" } })
        try await Task.sleep(for: .milliseconds(200))
        #expect(await reminders.updates.count == 2)
    }

    @Test func withRemindersOffAWriteDoesNotUseTheNotificationCenter() async throws {
        let reminders = RecordingReminders()
        let fixture = try ModelFixture(changes: Self.rice, reminders: reminders)
        defer { fixture.removeFolder() }
        let model = fixture.model
        model.start()
        // The first plan removes the reminders of an earlier start.
        #expect(await eventually { await reminders.updates == [[]] })

        model.perform(Self.milk(expires: "2026-05-10"))
        #expect(await eventually { model.content?.inventory.batches.count == 2 })
        model.refreshToday()
        try await Task.sleep(for: .milliseconds(200))
        #expect(await reminders.updates == [[]])
        #expect(await reminders.shownCalls == 1)

        // Reminders on: the plan has the reminders. Off again: the plan removes them one time.
        model.setRemindersOn(true)
        #expect(await eventually { await reminders.updates.count == 2 })
        #expect(await reminders.updates.last?.isEmpty == false)
        model.setRemindersOn(false)
        #expect(await eventually { await reminders.updates.count == 3 })
        #expect(await reminders.updates.last == [])
        #expect(model.reminders.settings?.nextDate == nil)
        model.perform(Self.milk(expires: "2026-05-20"))
        #expect(await eventually { model.content?.inventory.batches.count == 3 })
        try await Task.sleep(for: .milliseconds(200))
        #expect(await reminders.updates.count == 3)
    }

    // MARK: - The switch

    @Test func theAccessIsKnownWhenTheSettingsAreRead() async throws {
        let fixture = try ModelFixture(changes: Self.rice, reminders: RecordingReminders(access: .allowed))
        defer { fixture.removeFolder() }
        let model = fixture.model
        model.start()
        // Each time that a screen can show the switch, the model knows the access. With no access, a tap on the
        // switch explained the notifications also when they were allowed.
        var turns = 0
        while model.reminders == .loading && turns < 100_000 {
            await Task.yield()
            turns += 1
        }
        #expect(model.reminders != .loading)
        #expect(model.notificationAccess == .allowed)
    }

    @Test func theSwitchShowsTheSelectedValueWhileTheChangeWaits() async throws {
        let fixture = try ModelFixture(changes: Self.rice, reminders: RecordingReminders())
        defer { fixture.removeFolder() }
        let model = fixture.model
        model.start()
        #expect(await eventually { model.reminders.settings != nil })

        model.setRemindersOn(true)
        // The settings do not have the change yet. The switch does not go back.
        #expect(model.reminders.settings?.enabled == false)
        #expect(model.remindersSwitchOn)
        #expect(await eventually { model.reminders.settings?.enabled == true })
        #expect(model.remindersSwitchOn)

        // The newest selection decides.
        model.setRemindersOn(false)
        model.setRemindersOn(true)
        model.setRemindersOn(false)
        #expect(!model.remindersSwitchOn)
        #expect(await eventually { model.reminders.settings?.enabled == false })
        try await Task.sleep(for: .milliseconds(100))
        #expect(!model.remindersSwitchOn)
    }

    @Test func aSwitchChangeThatCannotBeSavedGoesBack() async throws {
        let fixture = try ModelFixture(changes: Self.rice, reminders: RecordingReminders())
        defer { fixture.removeFolder() }
        // A folder in the place of the file: the settings cannot be read or written.
        try FileManager.default.createDirectory(
            at: fixture.folder.appending(path: "reminders.json"),
            withIntermediateDirectories: true
        )
        let model = fixture.model
        model.start()
        #expect(await eventually { model.reminders == .unreadable })

        model.setRemindersOn(true)
        #expect(model.remindersSwitchOn)
        #expect(await eventually { model.notice?.text == .message(.settingsNotSaved) })
        #expect(!model.remindersSwitchOn)
        #expect(model.reminders == .unreadable)
    }
}
