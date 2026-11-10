import Foundation
import Testing
@testable import CVKEFridgeCore

/// Runs each case of `spec/vectors/calendar-date.json` (rule 2). The Android test `CalendarDateVectorsTest` runs the
/// same file.
struct CalendarDateVectorsTests {
    @Test func parseCases() throws {
        let file = try Vectors.load("calendar-date.json")
        for item in try Vectors.cases(file, "parse") {
            let text = try item.string("text")
            var actual: [String: Any] = ["valid": false]
            if let date = CalendarDate.parse(text) {
                actual = ["valid": true, "year": date.year, "month": date.month, "day": date.day]
            }
            try Vectors.check(actual, item.object("expect"), "parse \"\(text)\"")
        }
    }

    @Test func plusDaysCases() throws {
        let file = try Vectors.load("calendar-date.json")
        for item in try Vectors.cases(file, "plusDays") {
            let start = try Vectors.date(item.string("date"))
            let days = try item.int("days")
            let actual: [String: Any] = ["date": Vectors.orNull(start.plusDays(days)?.text)]
            try Vectors.check(actual, item.object("expect"), "plusDays \(start.text) \(days)")
        }
    }

    @Test func daysUntilCases() throws {
        let file = try Vectors.load("calendar-date.json")
        for item in try Vectors.cases(file, "daysUntil") {
            let start = try Vectors.date(item.string("from"))
            let end = try Vectors.date(item.string("to"))
            let actual: [String: Any] = ["days": start.daysUntil(end)]
            try Vectors.check(actual, item.object("expect"), "daysUntil from \(start.text) to \(end.text)")
        }
    }

    @Test func orderCases() throws {
        let file = try Vectors.load("calendar-date.json")
        for item in try Vectors.cases(file, "order") {
            let texts = try item.strings("dates")
            let dates = try texts.map { try Vectors.date($0) }
            let actual: [String: Any] = ["sorted": dates.sorted().map { $0.text }]
            try Vectors.check(actual, item.object("expect"), "order \(texts)")
        }
    }

    @Test func dateOfInstantCases() throws {
        let file = try Vectors.load("calendar-date.json")
        for item in try Vectors.cases(file, "dateOfInstant") {
            let millis = try item.int("epochMillis")
            let offset = try item.int("utcOffsetSeconds")
            let date = CalendarDate.ofInstant(epochMillis: millis, utcOffsetSeconds: offset)
            let actual: [String: Any] = ["date": Vectors.orNull(date?.text)]
            try Vectors.check(actual, item.object("expect"), "dateOfInstant \(millis) at offset \(offset)")
        }
    }
}
