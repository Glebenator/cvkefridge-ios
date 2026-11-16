import Testing
@testable import CVKEFridgeFeatures

/// The later expiry date for "+1 day", "+1 week", and an expired batch. The same cases as the Android LaterExpiryTest.
struct LaterExpiryTests {
    private let today = CalendarDate.parse("2026-11-13")!

    private func date(_ text: String) -> CalendarDate {
        CalendarDate.parse(text)!
    }

    @Test func anExpiringBatchGetsTheDaysAfterItsExpiryDate() {
        #expect(LaterExpiry.date(expiry: date("2026-11-14"), today: today, days: 1) == date("2026-11-15"))
        #expect(LaterExpiry.date(expiry: date("2026-11-13"), today: today, days: 7) == date("2026-11-20"))
    }

    @Test func anExpiredBatchGetsTheDaysAfterToday() {
        #expect(LaterExpiry.date(expiry: date("2026-11-10"), today: today, days: 1) == date("2026-11-14"))
        #expect(LaterExpiry.date(expiry: date("2026-11-12"), today: today, days: 7) == date("2026-11-20"))
    }

    @Test func aWeekGoesAcrossTheEndOfAMonthAndAYear() {
        #expect(LaterExpiry.date(expiry: date("2026-12-27"), today: date("2026-12-27"), days: 7) == date("2027-01-03"))
    }

    @Test func zeroDaysIsNotAChoice() {
        // Android throws an exception. The iOS rule gives no date.
        #expect(LaterExpiry.date(expiry: today, today: today, days: 0) == nil)
        #expect(LaterExpiry.date(expiry: today, today: today, days: -1) == nil)
    }

    @Test func aDateAfterTheLastDateIsNotAChoice() {
        // Android stops with an error here.
        #expect(LaterExpiry.date(expiry: date("9999-12-31"), today: today, days: 1) == nil)
    }

    // iOS correction of defect 6 of `docs/android-parity-plan.md`: the Android app accepts each date.
    @Test func aLaterDateIsAfterTheExpiryDateAndAfterToday() {
        // An expired batch: the first later date is tomorrow, also when the calendar opened before midnight.
        #expect(!LaterExpiry.isLater(today, expiry: date("2026-11-10"), today: today))
        #expect(LaterExpiry.isLater(date("2026-11-14"), expiry: date("2026-11-10"), today: today))
        // An expiring batch: the first later date is the day after its expiry date.
        #expect(!LaterExpiry.isLater(date("2026-11-15"), expiry: date("2026-11-15"), today: today))
        #expect(!LaterExpiry.isLater(date("2026-11-14"), expiry: date("2026-11-15"), today: today))
        #expect(LaterExpiry.isLater(date("2026-11-16"), expiry: date("2026-11-15"), today: today))
        // A batch with no expiry date: each date after today.
        #expect(!LaterExpiry.isLater(today, expiry: nil, today: today))
        #expect(LaterExpiry.isLater(date("2026-11-14"), expiry: nil, today: today))
        // The quick choices are always later.
        for days in LaterExpiry.quickDays {
            let expiry = date("2026-11-10")
            #expect(LaterExpiry.isLater(LaterExpiry.date(expiry: expiry, today: today, days: days)!, expiry: expiry, today: today))
        }
    }

    @Test func theQuickChoicesAreOneDayAndOneWeek() {
        #expect(LaterExpiry.quickDays == [1, 7])
    }
}
