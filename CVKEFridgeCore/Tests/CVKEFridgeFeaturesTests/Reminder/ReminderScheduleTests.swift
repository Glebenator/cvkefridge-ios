import CVKEFridgeFeatures
import Foundation
import Testing

/// The dates and the instants of the daily reminder across midnight, daylight saving time, and time zone changes. The
/// Android test `ReminderScheduleTest` has the same cases.
struct ReminderScheduleTests {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let denver = TimeZone(identifier: "America/Denver")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let nine = ReminderTime(hour: 9, minute: 0)!

    /// The instant of a local date and time `YYYY-MM-DDTHH:MM` in a time zone. The time must exist one time only.
    private func at(_ text: String, _ zone: TimeZone) -> Date {
        let parts = text.split(whereSeparator: { "-T:".contains($0) }).map { Int($0)! }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: parts[3], minute: parts[4])
        return calendar.date(from: components)!
    }

    /// The instant of a UTC text `YYYY-MM-DDTHH:MM:SSZ`.
    private func utc(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }

    private func day(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    private func time(_ hour: Int, _ minute: Int) -> ReminderTime {
        ReminderTime(hour: hour, minute: minute)!
    }

    @Test func theFirstReminderIsTodayWhenTheTimeIsAheadAndTomorrowWhenItPassed() {
        #expect(ReminderSchedule.firstDate(now: at("2026-11-12T08:59", berlin), timeZone: berlin, time: nine, lastDate: nil) == day("2026-11-12"))
        #expect(ReminderSchedule.firstDate(now: at("2026-11-12T09:00", berlin), timeZone: berlin, time: nine, lastDate: nil) == day("2026-11-13"))
        #expect(ReminderSchedule.firstDate(now: at("2026-11-12T23:59", berlin), timeZone: berlin, time: nine, lastDate: nil) == day("2026-11-13"))
        // A change of the time after the reminder of today does not give a second reminder today.
        #expect(
            ReminderSchedule.firstDate(now: at("2026-11-12T10:00", berlin), timeZone: berlin, time: time(18, 0), lastDate: day("2026-11-12"))
                == day("2026-11-13")
        )
    }

    @Test func theNextReminderAfterARunIsOnTheNextDateAlsoAcrossMidnight() {
        #expect(ReminderSchedule.dateAfterRun(day("2026-11-12")) == day("2026-11-13"))
        // A reminder at 23:30 that comes late at 00:20 belongs to the date on which it came.
        let late = at("2026-11-13T00:20", berlin)
        let ranOn = ReminderSchedule.dateOf(late, timeZone: berlin)
        #expect(ReminderSchedule.dateAfterRun(ranOn) == day("2026-11-14"))
        #expect(ReminderSchedule.triggerAt(day("2026-12-31"), time: time(23, 30), timeZone: berlin) == at("2026-12-31T23:30", berlin))
        #expect(
            ReminderSchedule.triggerAt(ReminderSchedule.dateAfterRun(day("2026-12-31")), time: nine, timeZone: berlin)
                == at("2027-01-01T09:00", berlin)
        )
    }

    @Test func theReminderStaysAtTheSameClockTimeWhenDaylightSavingTimeChanges() {
        // Berlin goes from UTC+1 to UTC+2 on 29 March 2026, and back on 25 October 2026.
        #expect(ReminderSchedule.triggerAt(day("2026-03-28"), time: nine, timeZone: berlin) == utc("2026-03-28T08:00:00Z"))
        #expect(ReminderSchedule.triggerAt(day("2026-03-29"), time: nine, timeZone: berlin) == utc("2026-03-29T07:00:00Z"))
        #expect(ReminderSchedule.triggerAt(day("2026-10-25"), time: nine, timeZone: berlin) == utc("2026-10-25T08:00:00Z"))
        // 02:30 does not exist on 29 March: the reminder moves forward by the gap of one hour.
        #expect(ReminderSchedule.triggerAt(day("2026-03-29"), time: time(2, 30), timeZone: berlin) == utc("2026-03-29T01:30:00Z"))
        // 02:30 exists two times on 25 October: the reminder is at the first.
        #expect(ReminderSchedule.triggerAt(day("2026-10-25"), time: time(2, 30), timeZone: berlin) == utc("2026-10-25T00:30:00Z"))
    }

    @Test func aTimeZoneChangeMovesTheReminderToTheSameClockTimeInTheNewZone() {
        let stored = day("2026-11-13")
        let now = at("2026-11-12T20:00", berlin)
        #expect(
            ReminderSchedule.restoredDate(stored: stored, now: now, timeZone: denver, time: nine, lastDate: day("2026-11-12"))
                == stored
        )
        #expect(ReminderSchedule.triggerAt(stored, time: nine, timeZone: denver) == at("2026-11-13T09:00", denver))
        #expect(ReminderSchedule.triggerAt(stored, time: nine, timeZone: tokyo) == at("2026-11-13T09:00", tokyo))
    }

    @Test func aMissedReminderOfTodayComesAtOnceAndOlderOnesDoNot() {
        // The phone was off at 09:00 and starts at 11:00. The reminder of today has its instant in the past.
        let boot = at("2026-11-12T11:00", berlin)
        let today = ReminderSchedule.restoredDate(stored: day("2026-11-12"), now: boot, timeZone: berlin, time: nine, lastDate: day("2026-11-11"))
        #expect(today == day("2026-11-12"))
        #expect(ReminderSchedule.triggerAt(today, time: nine, timeZone: berlin) < boot)
        // The phone was off for three days: only the reminder of today comes.
        #expect(
            ReminderSchedule.restoredDate(stored: day("2026-11-09"), now: boot, timeZone: berlin, time: nine, lastDate: day("2026-11-08"))
                == day("2026-11-12")
        )
        // A flight to the east: in Tokyo it is already 19:00, and the reminder of today did not come.
        let east = at("2026-11-12T19:00", tokyo)
        #expect(
            ReminderSchedule.restoredDate(stored: day("2026-11-12"), now: east, timeZone: tokyo, time: nine, lastDate: day("2026-11-11"))
                == day("2026-11-12")
        )
        // The reminder of today came: the next one is tomorrow.
        #expect(
            ReminderSchedule.restoredDate(stored: day("2026-11-12"), now: boot, timeZone: berlin, time: nine, lastDate: day("2026-11-12"))
                == day("2026-11-13")
        )
    }

    @Test func aClockThatGoesBackDoesNotStopTheRemindersForDays() {
        // The next reminder was on 20 November, and the clock goes back to 12 November.
        let now = at("2026-11-12T08:00", berlin)
        #expect(
            ReminderSchedule.restoredDate(stored: day("2026-11-20"), now: now, timeZone: berlin, time: nine, lastDate: day("2026-11-19"))
                == day("2026-11-12")
        )
        // A clock that goes back one hour after the reminder of today does not give a second reminder today.
        let back = at("2026-11-12T08:30", berlin)
        #expect(
            ReminderSchedule.restoredDate(stored: day("2026-11-13"), now: back, timeZone: berlin, time: nine, lastDate: day("2026-11-12"))
                == day("2026-11-13")
        )
    }

    @Test func aLastDateAfterTodayFromAClockThatWentBackIsForgotten() {
        let now = at("2026-11-12T16:30", denver)
        #expect(ReminderSchedule.knownLastDate(day("2026-11-13"), now: now, timeZone: denver) == nil)
        #expect(ReminderSchedule.knownLastDate(day("2026-11-12"), now: now, timeZone: denver) == day("2026-11-12"))
        // With the last date forgotten, the reminder of 13 November comes on 13 November.
        #expect(
            ReminderSchedule.restoredDate(stored: day("2026-11-14"), now: now, timeZone: denver, time: time(16, 20), lastDate: nil)
                == day("2026-11-13")
        )
    }

    @Test func noStoredDateGivesTheFirstDate() {
        #expect(
            ReminderSchedule.restoredDate(stored: nil, now: at("2026-11-12T07:00", berlin), timeZone: berlin, time: nine, lastDate: nil)
                == day("2026-11-12")
        )
    }

    // iOS: the time zone of a calculation is the one that the caller gives, not the time zone of the process.
    @Test func theDateAndTheMinuteOfAnInstantUseTheGivenTimeZone() {
        let instant = utc("2026-11-12T23:30:00Z")
        #expect(ReminderSchedule.dateOf(instant, timeZone: berlin) == day("2026-11-13"))
        #expect(ReminderSchedule.minuteOfDay(instant, timeZone: berlin) == 30)
        #expect(ReminderSchedule.dateOf(instant, timeZone: denver) == day("2026-11-12"))
        #expect(ReminderSchedule.minuteOfDay(instant, timeZone: denver) == 16 * 60 + 30)
        // A time zone with a half hour.
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!
        #expect(ReminderSchedule.triggerAt(day("2026-11-12"), time: nine, timeZone: kolkata) == utc("2026-11-12T03:30:00Z"))
        // An instant before 1970.
        #expect(ReminderSchedule.minuteOfDay(utc("1969-12-31T23:59:00Z"), timeZone: TimeZone(identifier: "UTC")!) == 23 * 60 + 59)
    }

    @Test func aTimeOfTheReminderIsInRange() {
        #expect(ReminderTime(hour: 24, minute: 0) == nil)
        #expect(ReminderTime(hour: 9, minute: 60) == nil)
        #expect(ReminderTime(minuteOfDay: 1440) == nil)
        #expect(ReminderTime(minuteOfDay: -1) == nil)
        #expect(ReminderTime(minuteOfDay: 7 * 60 + 5)?.description == "07:05")
    }
}
