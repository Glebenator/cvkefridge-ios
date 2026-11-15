import Foundation
import Testing
@testable import CVKEFridgeFeatures

/// The file of the products that the person removed from the recent foods. Android has no unit test for it.
struct RecentSettingsTests {
    private let jam = Product(id: "jam", name: "Jam", category: .condiment, unit: nil, barcode: nil, foodId: nil)

    @Test func theFileHasTheJSONShapeOfAndroid() throws {
        let settings = RecentSettings(hidden: ["jam": 20, "tea": 17])
        let text = String(decoding: try settings.encoded(), as: UTF8.self)
        #expect(text == #"{"hidden":{"jam":20,"tea":17}}"#)
        #expect(try RecentSettings.decode(Data(text.utf8)) == settings)
    }

    @Test func anEmptyFileAMissingValueAndAnUnknownKeyGiveTheDefaults() throws {
        #expect(try RecentSettings.decode(Data()) == RecentSettings())
        #expect(try RecentSettings.decode(Data(" \n".utf8)) == RecentSettings())
        #expect(try RecentSettings.decode(Data("{}".utf8)) == RecentSettings())
        #expect(try RecentSettings.decode(Data(#"{"hidden":{"a":1},"other":true}"#.utf8)) == RecentSettings(hidden: ["a": 1]))
    }

    @Test func aDamagedFileThrows() {
        #expect(throws: (any Error).self) { try RecentSettings.decode(Data("not json".utf8)) }
        #expect(throws: (any Error).self) { try RecentSettings.decode(Data(#"{"hidden":[1]}"#.utf8)) }
    }

    @Test func aRemovedFoodStaysRemovedWhenTheClockWentBack() {
        // The last change of jam has the instant 900, but the clock of the phone now says 100.
        let food = RecentFood(product: jam, at: 900)
        let hidden = RecentSettings().hiding(food, now: 100)
        #expect(hidden.hidden == ["jam": 900])
        #expect(AddAgain.shown([food], hidden: hidden.hidden) == [])
        // With a correct clock, the instant is the clock.
        #expect(RecentSettings().hiding(food, now: 1_000).hidden == ["jam": 1_000])
        // A later change shows the food again.
        #expect(AddAgain.shown([RecentFood(product: jam, at: 901)], hidden: hidden.hidden) == [jam])
    }
}
