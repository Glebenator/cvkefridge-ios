import Foundation
import Testing
@testable import CVKEFridgeCore

/// Runs each case of `spec/vectors/freshness.json` (rule 3). The Android test `FreshnessVectorsTest` runs the same
/// file.
struct FreshnessVectorsTests {
    @Test func freshnessCases() throws {
        let file = try Vectors.load("freshness.json")
        for item in try Vectors.cases(file, "cases") {
            let today = try Vectors.date(item.string("today"))
            let expiryText = try item.optionalString("expiryDate")
            var expiry: CalendarDate? = nil
            if let expiryText {
                expiry = try Vectors.date(expiryText)
            }
            let left = Freshness.daysLeft(today: today, expiryDate: expiry)
            let actual: [String: Any] = [
                "daysLeft": Vectors.orNull(left),
                "freshness": Freshness.of(daysLeft: left).rawValue,
            ]
            try Vectors.check(actual, item.object("expect"), "today \(today.text), expiry \(expiryText ?? "null")")
        }
    }
}
