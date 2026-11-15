import Foundation
import Testing
@testable import CVKEFridgeFeatures

/// The real table of foods, `spec/foods.json`. The root of the repository is five levels above this file:
/// `CVKEFridgeCore/Tests/CVKEFridgeFeaturesTests/Inventory/StorageAdviceTests.swift`.
private enum RealFoods {
    static let table: FoodTable = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("spec/foods.json")
        // A missing or damaged file stops the tests, so that a renamed file cannot pass.
        return try! FoodTable.decode(String(contentsOf: url, encoding: .utf8))
    }()
}

/// The storage tips of a food: the saved storage text, the time that a food keeps, and what the card shows. The same
/// cases as the Android StorageAdviceTest.
struct StorageAdviceTests {
    private let table = RealFoods.table

    @Test func aStorageTextIsSavedWithOneSpaceBetweenWordsAndNotMoreThanTheMaximum() throws {
        #expect(
            StorageTexts.clean("  Bei -18 °C\tlagern.\n\nNach dem Auftauen nicht wieder einfrieren. ")
                == "Bei -18 °C lagern. Nach dem Auftauen nicht wieder einfrieren."
        )
        #expect(StorageTexts.clean(nil) == nil)
        #expect(StorageTexts.clean(" \n ") == nil)
        let long = (1...120).map { "word\($0)" }.joined(separator: " ")
        let cleaned = try #require(StorageTexts.clean(long))
        // The text is cut after a whole word.
        #expect(cleaned.count <= StorageTexts.maxLength)
        #expect(long.hasPrefix("\(cleaned) "))
        #expect(StorageTexts.clean(String(repeating: "a", count: 600)) == String(repeating: "a", count: 500))
    }

    @Test func aStorageTextKeepsANoBreakSpaceAndIsNotCutInsideACharacter() throws {
        // A no-break space is not a space between words, as on Android.
        #expect(StorageTexts.clean("Bei -18\u{00A0}°C") == "Bei -18\u{00A0}°C")
        // A line break of Windows is one space.
        #expect(StorageTexts.clean("Keep cold.\r\nKeep dry.") == "Keep cold. Keep dry.")
        // Android counts UTF-16 units and can cut an emoji into two halves. The cut is after a whole character.
        let emoji = String(repeating: "a", count: 499) + String(repeating: "🧊", count: 10)
        let cleaned = try #require(StorageTexts.clean(emoji))
        #expect(cleaned == String(repeating: "a", count: 499) + "🧊")
        #expect(cleaned.count == StorageTexts.maxLength)
    }

    @Test func aTimeIsInTheLargestUnitThatGivesAWholeNumber() {
        #expect(KeepTime.ofDays(3) == KeepTime(count: 3, unit: .days))
        #expect(KeepTime.ofDays(14) == KeepTime(count: 2, unit: .weeks))
        #expect(KeepTime.ofDays(30) == KeepTime(count: 1, unit: .months))
        #expect(KeepTime.ofDays(60) == KeepTime(count: 2, unit: .months))
        // 210 days are 7 months, not 30 weeks.
        #expect(KeepTime.ofDays(210) == KeepTime(count: 7, unit: .months))
        #expect(KeepTime.ofDays(360) == KeepTime(count: 12, unit: .months))
        #expect(KeepTime.ofDays(365) == KeepTime(count: 1, unit: .years))
        #expect(KeepTime.ofDays(45) == KeepTime(count: 45, unit: .days))
    }

    @Test func theGeneralAdviceForBananasHasTheUsualPlaceTheTimesAndTheTipsOfTheTable() throws {
        let advice = try #require(StorageAdvices.of(storageText: nil, food: table.food(id: "fk-251")))
        #expect(advice.packageText == nil)
        #expect(
            advice.general == GeneralAdvice(
                foodName: "Bananas",
                usualKind: .pantry,
                kinds: [
                    KindAdvice(
                        kind: .pantry,
                        time: nil,
                        tip: "Ripe is when this item is tender, fully developed and ready to eat."
                    ),
                    KindAdvice(
                        kind: .fridge,
                        time: KeepTime(count: 3, unit: .days),
                        tip: "Timeline for refrigerator applies to ripe fruit; skin will blacken."
                    ),
                    KindAdvice(kind: .freezer, time: KeepTime(count: 2, unit: .months), tip: nil),
                ]
            )
        )
    }

    @Test func theStorageTextOfThePackageAndTheGeneralAdviceAreTwoParts() throws {
        let both = try #require(StorageAdvices.of(storageText: "Bei -18 °C lagern.", food: table.food(id: "fk-571")))
        #expect(both.packageText == "Bei -18 °C lagern.")
        #expect(both.general?.foodName == "Pizza")
        #expect(both.general?.usualKind == .freezer)

        // A product with no food of the table has the text of the package only.
        #expect(
            StorageAdvices.of(storageText: "Bei -18 °C lagern.", food: nil)
                == StorageAdvice(packageText: "Bei -18 °C lagern.", general: nil)
        )
        // With no storage text and no food, there is nothing to show.
        #expect(StorageAdvices.of(storageText: nil, food: nil) == nil)
        // A food with no usual storage kind, no days, and no tip has no general advice.
        let bare = Food(id: "x", name: "Thing", subtitle: nil, category: .other, keywords: [], days: [:])
        #expect(StorageAdvices.of(storageText: nil, food: bare) == nil)
        #expect(
            StorageAdvices.of(storageText: "Keep dry.", food: bare) == StorageAdvice(packageText: "Keep dry.", general: nil)
        )
    }
}
