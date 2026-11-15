import CVKEFridgeFeatures
import Foundation
import Testing

/// The reminders that the iOS app plans ahead (see `ReminderPlan`). Each planned reminder must have the content that
/// the receiver of Android computes on its date.
struct ReminderPlanTests {
    private typealias I = ReminderInventory
    private let today = I.date("2026-11-12")
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func settings(
        enabled: Bool = true,
        at minuteOfDay: Int = 9 * 60,
        leadDays: Int = 2,
        lastDate: String? = nil
    ) -> ReminderSettings {
        ReminderSettings(enabled: enabled, minuteOfDay: minuteOfDay, leadDays: leadDays, lastDate: lastDate)
    }

    /// The plan at the `minute` of today in UTC, a time zone with no change of the clock.
    private func plan(
        _ inventory: Inventory,
        _ settings: ReminderSettings,
        now minute: Int = 8 * 60,
        horizonDays: Int? = nil,
        maxReminders: Int = ReminderPlan.defaultMaxReminders
    ) -> [PlannedReminder] {
        let utc = TimeZone(identifier: "UTC")!
        let now = ReminderSchedule.triggerAt(today, time: ReminderTime(minuteOfDay: minute)!, timeZone: utc)
        return ReminderPlan.reminders(
            inventory: inventory,
            settings: settings,
            now: now,
            timeZone: utc,
            horizonDays: horizonDays,
            maxReminders: maxReminders
        )
    }

    private func dates(_ reminders: [PlannedReminder]) -> [String] {
        reminders.map(\.date.text)
    }

    /// One product "milk" with one batch that expires on `expires`.
    private func milk(expires: String, source: ExpirySource = .printed) -> Inventory {
        I.inventory(I.product("milk", "Whole milk"), I.batch("b1", "milk", expires: expires, source: source))
    }

    @Test func remindersThatAreOffGiveNoPlan() {
        #expect(plan(milk(expires: "2026-11-13"), settings(enabled: false)).isEmpty)
        #expect(plan(milk(expires: "2026-11-13"), ReminderSettings.defaults).isEmpty)
    }

    @Test func aDateWithNothingToSayHasNoReminder() {
        // No food, no expiry date, a batch that is used, and a batch that expires after a horizon of two weeks.
        #expect(plan(I.inventory(), settings()).isEmpty)
        let inventory = I.inventory(
            I.product("rice"),
            I.product("milk"),
            I.product("jam"),
            I.batch("b1", "rice", expires: nil),
            I.batch("b2", "milk", expires: "2026-11-13"),
            .batchUsed(batchId: "b2", quantity: 1000, date: today),
            I.batch("b3", "jam", expires: "2027-03-01")
        )
        #expect(plan(inventory, settings(), horizonDays: ReminderPlan.defaultHorizonDays).isEmpty)
        // With no horizon, only the dates near the expiry date of jam have something to say.
        #expect(dates(plan(inventory, settings())) == ["2027-02-27", "2027-02-28", "2027-03-01", "2027-03-02"])
    }

    @Test func aBatchThatExpiresInThePlanIsInTheRemindersFromTheLeadTimeToTheDayAfter() {
        let reminders = plan(milk(expires: "2026-11-16", source: .estimated), settings())
        #expect(dates(reminders) == ["2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17"])
        #expect(reminders.map { $0.foods.map(\.daysLeft) } == [[2], [1], [0], [-1]])
        #expect(reminders.allSatisfy { $0.foods.map(\.estimated) == [true] })
        #expect(reminders.allSatisfy { $0.time == ReminderTime(hour: 9, minute: 0) })
        // Each reminder has the foods that the rules give on its date, as on Android.
        for reminder in reminders {
            #expect(reminder.foods == ReminderRules.foods(milk(expires: "2026-11-16", source: .estimated), today: reminder.date, leadDays: 2))
        }
        #expect(reminders[2].message.lines.map(\.daysLeft) == [.expiresToday])
    }

    @Test func theLeadTimeDecidesTheFirstReminder() {
        let inventory = milk(expires: "2026-11-16")
        #expect(dates(plan(inventory, settings(leadDays: 0))) == ["2026-11-16", "2026-11-17"])
        #expect(dates(plan(inventory, settings(leadDays: 1))) == ["2026-11-15", "2026-11-16", "2026-11-17"])
        #expect(dates(plan(inventory, settings(leadDays: 2))) == ["2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17"])
        // A lead time out of range gets the default.
        #expect(dates(plan(inventory, settings(leadDays: 9))) == ["2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17"])
    }

    @Test func anExpiredBatchIsOnlyInTheReminderOfTheFirstDayAfterItsExpiryDate() {
        // It expired yesterday: today's reminder names it, and no later reminder does.
        let yesterday = plan(milk(expires: "2026-11-11"), settings())
        #expect(dates(yesterday) == ["2026-11-12"])
        #expect(yesterday.first?.foods.map(\.daysLeft) == [-1])
        // It expired two days ago: no reminder names it.
        #expect(plan(milk(expires: "2026-11-10"), settings()).isEmpty)
        // It expired yesterday, but the time of today's reminder passed: no reminder names it.
        #expect(plan(milk(expires: "2026-11-11"), settings(), now: 10 * 60).isEmpty)
    }

    @Test func todayIsPlannedOnlyWhenItsTimeIsAhead() {
        let inventory = milk(expires: "2026-11-12")
        #expect(dates(plan(inventory, settings(), now: 8 * 60 + 59)) == ["2026-11-12", "2026-11-13"])
        // At the minute of the reminder, its time has passed.
        #expect(dates(plan(inventory, settings(), now: 9 * 60)) == ["2026-11-13"])
        #expect(dates(plan(inventory, settings(), now: 23 * 60)) == ["2026-11-13"])
    }

    @Test func todayIsNotPlannedAgainAfterItsReminder() {
        // The person moved the time from 09:00 to 18:00 after the reminder of today.
        let inventory = milk(expires: "2026-11-12")
        #expect(dates(plan(inventory, settings(at: 18 * 60, lastDate: "2026-11-12"), now: 10 * 60)) == ["2026-11-13"])
        // A last date of an earlier day has no effect.
        #expect(dates(plan(inventory, settings(at: 18 * 60, lastDate: "2026-11-11"), now: 10 * 60)) == ["2026-11-12", "2026-11-13"])
    }

    @Test func aReminderAtMidnightIsOnItsDate() {
        let inventory = milk(expires: "2026-11-13")
        // At 00:00 the reminder of today has passed. The next one is at the start of tomorrow.
        #expect(dates(plan(inventory, settings(at: 0), now: 0)) == ["2026-11-13", "2026-11-14"])
        // At 23:59 a reminder at 23:59 has passed too, and one minute before it is ahead.
        #expect(dates(plan(inventory, settings(at: 23 * 60 + 59), now: 23 * 60 + 59)) == ["2026-11-13", "2026-11-14"])
        #expect(dates(plan(inventory, settings(at: 23 * 60 + 59), now: 23 * 60 + 58)) == ["2026-11-12", "2026-11-13", "2026-11-14"])
        // With the instant of now: one second before midnight, the date is still 12 November.
        let beforeMidnight = try! Date("2026-11-12T22:59:59Z", strategy: .iso8601)
        let reminders = ReminderPlan.reminders(inventory: inventory, settings: settings(at: 0), now: beforeMidnight, timeZone: berlin)
        #expect(dates(reminders) == ["2026-11-13", "2026-11-14"])
        #expect(reminders.first?.triggerAt(timeZone: berlin) == (try! Date("2026-11-12T23:00:00Z", strategy: .iso8601)))
        // At midnight exactly, the reminder of that date has passed.
        let midnight = try! Date("2026-11-12T23:00:00Z", strategy: .iso8601)
        #expect(dates(ReminderPlan.reminders(inventory: inventory, settings: settings(at: 0), now: midnight, timeZone: berlin)) == ["2026-11-14"])
    }

    @Test func aHorizonStopsThePlanAtItsLastDate() {
        // Today and 13 more dates: the last date is 25 November.
        let twoWeeks = ReminderPlan.defaultHorizonDays
        #expect(dates(plan(milk(expires: "2026-11-27"), settings(), horizonDays: twoWeeks)) == ["2026-11-25"])
        #expect(plan(milk(expires: "2026-11-28"), settings(), horizonDays: twoWeeks).isEmpty)
        #expect(dates(plan(milk(expires: "2026-11-28"), settings(), horizonDays: 15)) == ["2026-11-26"])
        #expect(plan(milk(expires: "2026-11-12"), settings(), horizonDays: 0).isEmpty)
        #expect(dates(plan(milk(expires: "2026-11-12"), settings(), horizonDays: 1)) == ["2026-11-12"])
    }

    // A plan of 14 days left a food that expires in 30 days with no reminder when the app did not open.
    @Test func thePlanGoesToTheDayAfterTheLatestExpiryDate() {
        let reminders = plan(milk(expires: "2026-12-12"), settings())
        #expect(dates(reminders) == ["2026-12-10", "2026-12-11", "2026-12-12", "2026-12-13"])
        #expect(reminders.map { $0.foods.map(\.daysLeft) } == [[2], [1], [0], [-1]])
        // A far expiry date has its reminders too.
        #expect(dates(plan(milk(expires: "2031-01-01"), settings(leadDays: 0))) == ["2031-01-01", "2031-01-02"])
    }

    @Test func thePlanHasNotMoreThanTheLargestNumberOfRemindersTheEarliestFirst() {
        // One batch that expires each fourth day: four reminders for each batch, 80 dates in all.
        var bodies: [ChangeBody] = []
        for index in 0..<20 {
            let expires = today.plusDays(3 + index * 4)!.text
            bodies.append(I.product("p\(index)"))
            bodies.append(I.batch("b\(index)", "p\(index)", expires: expires))
        }
        let inventory = I.inventory(bodies)
        let reminders = plan(inventory, settings())
        #expect(reminders.count == ReminderPlan.defaultMaxReminders)
        #expect(reminders.first?.date.text == "2026-11-13")
        #expect(reminders.map(\.date) == reminders.map(\.date).sorted())
        #expect(plan(inventory, settings(), maxReminders: 5).map(\.date) == Array(reminders.prefix(5)).map(\.date))
        #expect(plan(inventory, settings(), maxReminders: 0).isEmpty)
        // The same reminders as the rules give on each date.
        for reminder in reminders {
            #expect(reminder.foods == ReminderRules.foods(inventory, today: reminder.date, leadDays: 2))
        }
    }

    @Test func eachReminderHasAllItsFoodsInTheOrderOfTheRules() {
        let inventory = I.inventory(
            I.product("a", "yoghurt"),
            I.product("b", "Apples"),
            I.product("c", "bread"),
            I.batch("b1", "a", expires: "2026-11-14"),
            I.batch("b2", "b", expires: "2026-11-14"),
            I.batch("b3", "c", expires: "2026-11-13")
        )
        let reminders = plan(inventory, settings())
        #expect(dates(reminders) == ["2026-11-12", "2026-11-13", "2026-11-14", "2026-11-15"])
        #expect(reminders.map { $0.foods.map(\.name) } == [
            ["bread", "Apples", "yoghurt"],
            ["bread", "Apples", "yoghurt"],
            // Bread expired yesterday, so it is first.
            ["bread", "Apples", "yoghurt"],
            // Bread expired two days ago, so it is not there.
            ["Apples", "yoghurt"],
        ])
        #expect(reminders[1].foods.map(\.daysLeft) == [0, 1, 1])
        #expect(reminders[2].foods.map(\.daysLeft) == [-1, 0, 0])
        #expect(reminders[1].message.count == 3)
    }

    @Test func theInstantOfNowDecidesTodayInTheTimeZone() {
        let inventory = milk(expires: "2026-11-13")
        // 08:30 in Berlin is 07:30 UTC: the reminder of today at 09:00 is ahead.
        let now = try! Date("2026-11-12T07:30:00Z", strategy: .iso8601)
        let reminders = ReminderPlan.reminders(inventory: inventory, settings: settings(), now: now, timeZone: berlin)
        #expect(dates(reminders) == ["2026-11-12", "2026-11-13", "2026-11-14"])
        #expect(reminders.first?.triggerAt(timeZone: berlin) == (try! Date("2026-11-12T08:00:00Z", strategy: .iso8601)))
        // In Tokyo it is 16:30 on the same instant: the time of today passed.
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        #expect(dates(ReminderPlan.reminders(inventory: inventory, settings: settings(), now: now, timeZone: tokyo)) == ["2026-11-13", "2026-11-14"])
    }

    // The minute of now cannot tell the two hours of an autumn change of the clock apart. The instant can.
    @Test func inTheHourThatTheClockRepeatsTheReminderIsAtTheFirstTime() {
        // Berlin goes from 03:00 back to 02:00 on 25 October 2026. 02:30 is 00:30 UTC and 01:30 UTC.
        let inventory = milk(expires: "2026-10-26")
        let settings = settings(at: 2 * 60 + 30)
        // At the first 02:10 (00:10 UTC), the reminder of today is ahead.
        let first = try! Date("2026-10-25T00:10:00Z", strategy: .iso8601)
        let early = ReminderPlan.reminders(inventory: inventory, settings: settings, now: first, timeZone: berlin)
        #expect(dates(early) == ["2026-10-25", "2026-10-26", "2026-10-27"])
        #expect(early.first?.triggerAt(timeZone: berlin) == (try! Date("2026-10-25T00:30:00Z", strategy: .iso8601)))
        // At the second 02:10 (01:10 UTC), the reminder at the first 02:30 has passed.
        let second = try! Date("2026-10-25T01:10:00Z", strategy: .iso8601)
        #expect(dates(ReminderPlan.reminders(inventory: inventory, settings: settings, now: second, timeZone: berlin))
            == ["2026-10-26", "2026-10-27"])
    }

    @Test func aTimeThatTheClockSkipsIsLaterByTheGap() {
        // Berlin skips 02:00 to 03:00 on 29 March 2026. A reminder at 02:30 comes at 03:30, so at 03:10 it is ahead.
        let inventory = milk(expires: "2026-03-29")
        let now = try! Date("2026-03-29T01:10:00Z", strategy: .iso8601)
        let reminders = ReminderPlan.reminders(inventory: inventory, settings: settings(at: 2 * 60 + 30), now: now, timeZone: berlin)
        #expect(dates(reminders) == ["2026-03-29", "2026-03-30"])
        #expect(reminders.first?.triggerAt(timeZone: berlin) == (try! Date("2026-03-29T01:30:00Z", strategy: .iso8601)))
    }

    @Test func aTimeOutOfRangeGetsTheDefaultTime() {
        let reminders = plan(milk(expires: "2026-11-13"), settings(at: 2000))
        #expect(reminders.first?.time == ReminderTime(hour: 9, minute: 0))
        #expect(dates(reminders) == ["2026-11-12", "2026-11-13", "2026-11-14"])
    }

    // MARK: The notification of a planned reminder

    private func reminder(on date: String, at minuteOfDay: Int) -> PlannedReminder {
        PlannedReminder(
            date: I.date(date),
            time: ReminderTime(minuteOfDay: minuteOfDay)!,
            foods: [ReminderFood(productId: "milk", name: "Whole milk", daysLeft: 0, estimated: false)]
        )
    }

    private func instant(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }

    @Test func eachDateHasOneIdentifierThatGivesTheDateBack() {
        let reminder = reminder(on: "2026-11-14", at: 9 * 60)
        #expect(reminder.identifier == "reminder-2026-11-14")
        #expect(PlannedReminder.date(ofIdentifier: reminder.identifier) == I.date("2026-11-14"))
        // The time is not in the identifier: a new time replaces the notification of the same date.
        #expect(self.reminder(on: "2026-11-14", at: 18 * 60).identifier == reminder.identifier)
        #expect(PlannedReminder.date(ofIdentifier: "test-reminder") == nil)
        #expect(PlannedReminder.date(ofIdentifier: "reminder-") == nil)
        #expect(PlannedReminder.date(ofIdentifier: "reminder-2026-02-30") == nil)
        #expect(PlannedReminder.date(ofIdentifier: "2026-11-14") == nil)
    }

    @Test func theTriggerHasTheFullDateAndTimeInTheTimeZone() {
        let components = reminder(on: "2026-11-14", at: 9 * 60 + 5).triggerComponents(timeZone: berlin)
        #expect(components.year == 2026)
        #expect(components.month == 11)
        #expect(components.day == 14)
        #expect(components.hour == 9)
        #expect(components.minute == 5)
        #expect(components.second == 0)
        #expect(components.timeZone == berlin)
        #expect(components.calendar?.identifier == .gregorian)
        #expect(components.date == instant("2026-11-14T08:05:00Z"))
    }

    @Test func theTriggerOfATimeThatTheClockSkipsIsATimeThatExists() {
        // On 29 March 2026 the clock of Berlin skips from 02:00 to 03:00. A reminder at 02:30 comes at 03:30.
        let components = reminder(on: "2026-03-29", at: 2 * 60 + 30).triggerComponents(timeZone: berlin)
        #expect(components.day == 29)
        #expect(components.hour == 3)
        #expect(components.minute == 30)
        #expect(components.date == instant("2026-03-29T01:30:00Z"))
    }

    @Test func theTriggerInTheHourThatTheClockRepeatsIsTheFirstTime() {
        // On 25 October 2026 the clock of Berlin goes back from 03:00 to 02:00. A reminder at 02:30 comes the first
        // time that the clock shows 02:30.
        let components = reminder(on: "2026-10-25", at: 2 * 60 + 30).triggerComponents(timeZone: berlin)
        #expect(components.hour == 2)
        #expect(components.minute == 30)
        #expect(components.date == instant("2026-10-25T00:30:00Z"))
    }

    @Test func theTriggerStaysGregorianForEachCalendarOfThePerson() {
        // The year 2026 of the Gregorian calendar is the year 8 of the Japanese calendar. The components stay
        // Gregorian, so the trigger is on the correct day.
        let components = reminder(on: "2026-11-14", at: 9 * 60).triggerComponents(timeZone: berlin)
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = berlin
        #expect(components.year == 2026)
        #expect(components.calendar?.date(from: components) == instant("2026-11-14T08:00:00Z"))
        #expect(japanese.component(.year, from: instant("2026-11-14T08:00:00Z")) == 8)
    }
}
