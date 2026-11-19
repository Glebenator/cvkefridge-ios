import CVKEFridgeFeatures
import Foundation
import Testing
import UserNotifications
@testable import CVKEFridge

/// The calendar trigger of a planned reminder, as iOS reads it (`UNCalendarNotificationTrigger.nextTriggerDate()`).
/// iOS reads the trigger in the time zone of the app, so each test sets that time zone and then sets it back.
@MainActor
@Suite(.serialized)
struct ReminderTriggerTests {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func reminder(on date: String, at minuteOfDay: Int) -> PlannedReminder {
        PlannedReminder(
            date: CalendarDate.parse(date)!,
            time: ReminderTime(minuteOfDay: minuteOfDay)!,
            foods: [ReminderFood(productId: "milk", name: "Milk", daysLeft: 0, estimated: false)]
        )
    }

    /// The next instant of the trigger when the device is in the `zone`.
    private func nextFire(_ components: DateComponents, in zone: TimeZone) -> Date? {
        let before = NSTimeZone.default
        NSTimeZone.default = zone
        defer { NSTimeZone.default = before }
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false).nextTriggerDate()
    }

    private func instant(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }

    @Test func aTimeThatTheClockSkipsComesOneTimeLaterByTheGap() {
        // On 28 March 2027 the clock of Berlin skips from 02:00 to 03:00. iOS gives the reminder at 02:30 at 03:30.
        let components = reminder(on: "2027-03-28", at: 2 * 60 + 30).triggerComponents(timeZone: berlin)
        #expect(nextFire(components, in: berlin) == instant("2027-03-28T01:30:00Z"))
    }

    @Test func aTimeThatTheClockSkipsInTheOldTimeZoneComesAtItsTimeInTheNewTimeZone() {
        // Planned in Berlin. The person travels to Tokyo and does not open the app: the reminder comes at 02:30 there.
        let components = reminder(on: "2027-03-28", at: 2 * 60 + 30).triggerComponents(timeZone: berlin)
        #expect(nextFire(components, in: TimeZone(identifier: "Asia/Tokyo")!) == instant("2027-03-27T17:30:00Z"))
    }

    @Test func aTimeThatTheClockRepeatsComesAtTheFirstTime() {
        // On 31 October 2027 the clock of Berlin goes back from 03:00 to 02:00.
        let components = reminder(on: "2027-10-31", at: 2 * 60 + 30).triggerComponents(timeZone: berlin)
        #expect(nextFire(components, in: berlin) == instant("2027-10-31T00:30:00Z"))
    }
}
