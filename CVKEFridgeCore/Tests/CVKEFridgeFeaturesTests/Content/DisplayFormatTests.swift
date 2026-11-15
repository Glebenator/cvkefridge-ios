import Foundation
import Testing
@testable import CVKEFridgeFeatures

/// The values that the screens turn into words. Android makes the words in Compose and has no unit test for them.
struct DisplayFormatTests {
    private let date = CalendarDate.parse("2026-11-11")!

    @Test func theNumberOfAQuantityHasTheFormatOfTheLocale() {
        let english = Locale(identifier: "en_US")
        let german = Locale(identifier: "de_DE")
        #expect(QuantityDisplay(thousandths: 1_500, unit: .l).number(locale: english) == "1.5")
        #expect(QuantityDisplay(thousandths: 1_500, unit: .l).number(locale: german) == "1,5")
        #expect(QuantityDisplay(thousandths: 125, unit: .kg).number(locale: english) == "0.125")
        #expect(QuantityDisplay(thousandths: 3_000, unit: nil).number(locale: english) == "3")
        #expect(QuantityDisplay(thousandths: 12_345_500, unit: .g).number(locale: english) == "12,345.5")
        #expect(QuantityDisplay(thousandths: 12_345_500, unit: .g).number(locale: german) == "12.345,5")
        #expect(QuantityDisplay(thousandths: 1_500, unit: .l).value == Decimal(string: "1.5"))
    }

    @Test func thePluralCountIsTheWholeNumberOrNoneForAFraction() {
        #expect(QuantityDisplay(thousandths: 1_000, unit: .pack).pluralCount == 1)
        // Android uses the form for 2 for 5 packs. Some languages have another form for 5.
        #expect(QuantityDisplay(thousandths: 5_000, unit: .pack).pluralCount == 5)
        #expect(QuantityDisplay(thousandths: 1_500, unit: .pack).pluralCount == nil)
    }

    @Test func theExpiryTextHasTheSameWordsOnTheTwoScreens() {
        let printed = ExpiryDate(date: date, source: .printed)
        func phrase(_ daysLeft: Int) -> ExpiryPhrase {
            ExpiryText.of(daysLeft: daysLeft, expiry: printed).phrase
        }
        #expect(phrase(-3) == .expiredDaysAgo(3))
        #expect(phrase(-2) == .expiredDaysAgo(2))
        #expect(phrase(-1) == .expiredYesterday)
        #expect(phrase(0) == .expiresToday)
        #expect(phrase(1) == .expiresTomorrow)
        #expect(phrase(5) == .expiresInDays(5))
        #expect(!ExpiryText.of(daysLeft: 5, expiry: printed).estimated)
    }

    @Test func anEstimatedDateIsMarkedAndNoDateIsNoExpiry() {
        let estimated = ExpiryDate(date: date, source: .estimated)
        #expect(ExpiryText.of(daysLeft: 2, expiry: estimated) == ExpiryText(phrase: .expiresInDays(2), estimated: true))
        #expect(ExpiryText.of(daysLeft: nil, expiry: nil) == ExpiryText(phrase: .noExpiry, estimated: false))
        #expect(ExpiryText.of(daysLeft: nil, expiry: estimated) == ExpiryText(phrase: .noExpiry, estimated: false))
        // A chosen date is not an estimate.
        let chosen = ExpiryDate(date: date, source: .chosen)
        #expect(!ExpiryText.of(daysLeft: 0, expiry: chosen).estimated)
    }
}
