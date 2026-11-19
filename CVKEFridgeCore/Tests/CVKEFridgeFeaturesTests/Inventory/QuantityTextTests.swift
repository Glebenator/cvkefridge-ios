import Foundation
import Testing
@testable import CVKEFridgeFeatures

/// The text of a quantity field, to and from thousandths. The same cases as the Android QuantityTextTest, and the
/// corrections for locales.
struct QuantityTextTests {
    @Test func aNumberWithAPointOrACommaIsAQuantity() {
        #expect(QuantityText.parse("1") == .value(1_000))
        #expect(QuantityText.parse(" 1.5 ") == .value(1_500))
        #expect(QuantityText.parse("1,5") == .value(1_500))
        #expect(QuantityText.parse(".25") == .value(250))
        #expect(QuantityText.parse("2.") == .value(2_000))
        #expect(QuantityText.parse("0.001") == .value(1))
        #expect(QuantityText.parse("099999.999") == .value(99_999_999))
    }

    @Test func otherTextHasAReason() {
        #expect(QuantityText.parse("  ") == .invalid(.empty))
        #expect(QuantityText.parse("two") == .invalid(.notANumber))
        #expect(QuantityText.parse(".") == .invalid(.notANumber))
        #expect(QuantityText.parse("-1") == .invalid(.notANumber))
        #expect(QuantityText.parse("1.2.3") == .invalid(.notANumber))
        #expect(QuantityText.parse("1 000") == .invalid(.notANumber))
        #expect(QuantityText.parse("0.0001") == .invalid(.tooManyDecimals))
        #expect(QuantityText.parse("0") == .invalid(.notPositive))
        #expect(QuantityText.parse("0,000") == .invalid(.notPositive))
        #expect(QuantityText.parse("100000") == .invalid(.tooLarge))
    }

    @Test func theTextOfAQuantityHasNoZerosAtTheEnd() {
        #expect(QuantityText.format(1_000) == "1")
        #expect(QuantityText.format(1_500) == "1.5")
        #expect(QuantityText.format(125, decimalSeparator: ",") == "0,125")
        #expect(QuantityText.format(600_000) == "600")
    }

    @Test func theTextOfAnArabicLocaleIsAQuantityAgain() {
        // Android writes "1٫5" for an Arabic locale, and then cannot read it.
        let arabicSign = "\u{066B}"
        let text = QuantityText.format(1_500, decimalSeparator: arabicSign)
        #expect(text == "1\u{066B}5")
        #expect(QuantityText.parse(text) == .value(1_500))
        // The decimal keyboard of iOS can type the Arabic-Indic digits.
        #expect(QuantityText.parse("\u{0661}\u{066B}\u{0665}") == .value(1_500))
        #expect(QuantityText.parse("\u{0662}\u{0665}\u{0660}") == .value(250_000))
        // A number that is not a decimal digit is not a digit.
        #expect(QuantityText.parse("\u{00BD}") == .invalid(.notANumber))
        #expect(QuantityText.parse("1\u{066B}2.3") == .invalid(.notANumber))
    }

    @Test func theConveniencesGiveTheValueOrTheProblem() {
        #expect(QuantityText.parse("2").thousandths == 2_000)
        #expect(QuantityText.parse("2").problem == nil)
        #expect(QuantityText.parse("").thousandths == nil)
        #expect(QuantityText.parse("").problem == .empty)
    }

    // Correction of QuantityText.kt: "1.000" with a German locale was 1, and "1.000,5" was not a number.
    @Test func theLocaleDecidesTheSignForThousandsAndTheDecimalSign() {
        let german = Locale(identifier: "de_DE")
        #expect(QuantityText.parse("1.000", locale: german) == .value(1_000_000))
        #expect(QuantityText.parse("1.000,5", locale: german) == .value(1_000_500))
        #expect(QuantityText.parse("1,5", locale: german) == .value(1_500))
        #expect(QuantityText.parse(",25", locale: german) == .value(250))
        // A point that is not in groups of three digits is the decimal sign of a keyboard with only a point.
        #expect(QuantityText.parse("1.5", locale: german) == .value(1_500))
        #expect(QuantityText.parse("1.00", locale: german) == .value(1_000))
        #expect(QuantityText.parse("1.000.000", locale: german) == .invalid(.tooLarge))
        #expect(QuantityText.parse("1.000,5,5", locale: german) == .invalid(.notANumber))
        #expect(QuantityText.parse("1,000.5", locale: german) == .invalid(.notANumber))
        #expect(QuantityText.parse("1.2.3", locale: german) == .invalid(.notANumber))

        let english = Locale(identifier: "en_US")
        #expect(QuantityText.parse("1,000", locale: english) == .value(1_000_000))
        #expect(QuantityText.parse("1,000.5", locale: english) == .value(1_000_500))
        #expect(QuantityText.parse("1.5", locale: english) == .value(1_500))
        #expect(QuantityText.parse("1,5", locale: english) == .value(1_500))
        #expect(QuantityText.parse("12,34,567", locale: english) == .invalid(.tooLarge))

        // A space is the sign for thousands in French: each kind of space.
        let french = Locale(identifier: "fr_FR")
        #expect(QuantityText.parse("1 000,5", locale: french) == .value(1_000_500))
        #expect(QuantityText.parse("1\u{202F}000,5", locale: french) == .value(1_000_500))
        #expect(QuantityText.parse("1\u{00A0}000", locale: french) == .value(1_000_000))

        // The groups of India: 2 digits between the first and the last group.
        #expect(QuantityText.parse("99,999.5", locale: Locale(identifier: "en_IN")) == .value(99_999_500))
        // Switzerland: the sign U+2019, and also the ASCII apostrophe of the keyboard.
        let swiss = Locale(identifier: "de_CH")
        #expect(QuantityText.parse("1\u{2019}000.25", locale: swiss) == .value(1_000_250))
        #expect(QuantityText.parse("1\u{0027}000.25", locale: swiss) == .value(1_000_250))
        // Arabic: the Arabic sign for thousands and the Arabic-Indic digits.
        let arabic = Locale(identifier: "ar_EG")
        #expect(QuantityText.parse("\u{0661}\u{066C}\u{0660}\u{0660}\u{0660}\u{066B}\u{0665}", locale: arabic) == .value(1_000_500))
    }

    @Test func theLimitsOfALocaleAreTheLimitsOfAndroid() {
        let german = Locale(identifier: "de_DE")
        #expect(QuantityText.parse("  ", locale: german) == .invalid(.empty))
        #expect(QuantityText.parse("zwei", locale: german) == .invalid(.notANumber))
        #expect(QuantityText.parse(",", locale: german) == .invalid(.notANumber))
        #expect(QuantityText.parse("-1", locale: german) == .invalid(.notANumber))
        #expect(QuantityText.parse("0,0001", locale: german) == .invalid(.tooManyDecimals))
        #expect(QuantityText.parse("0", locale: german) == .invalid(.notPositive))
        #expect(QuantityText.parse("99.999,999", locale: german) == .value(99_999_999))
        #expect(QuantityText.parse("100.000", locale: german) == .invalid(.tooLarge))
        #expect(QuantityText.parse("0,001", locale: german) == .value(1))
    }

    // Correction of QuantityText.kt:22: a quantity that the app formatted for a locale with other digits or another
    // decimal sign could not be read again.
    @Test func theTextOfEachLocaleIsReadAgainAsTheSameThousandths() {
        let values = [1, 10, 125, 999, 1_000, 1_001, 1_500, 12_345, 99_999_999]
        for identifier in Locale.availableIdentifiers {
            let locale = Locale(identifier: identifier)
            for value in values {
                let text = QuantityText.format(value, locale: locale)
                #expect(QuantityText.parse(text, locale: locale) == .value(value), "\(identifier): \(text)")
            }
        }
        #expect(QuantityText.format(1_500, locale: Locale(identifier: "de_DE")) == "1,5")
        #expect(QuantityText.format(12_345_000, locale: Locale(identifier: "en_US")) == "12345")
        #expect(QuantityText.format(1_500, locale: Locale(identifier: "ar_EG")) == "\u{0661}\u{066B}\u{0665}")
        // The text of `format(_:decimalSeparator:)` with the sign of the locale is read again too.
        #expect(QuantityText.parse(QuantityText.format(1_500, decimalSeparator: ","), locale: Locale(identifier: "de_DE")) == .value(1_500))
    }

    @Test func theFormsReadTheQuantityWithTheLocale() throws {
        let german = Locale(identifier: "de_DE")
        let today = CalendarDate.parse("2026-11-12")!
        let noFoods = FoodTable(foods: [])
        let form = AddFoodForm(name: "Reis", quantity: "1.000", unit: .g)
        #expect(form.quantityError(locale: german) == nil)
        let action = try #require(form.action(products: [], areas: [StorageArea.fridge], foods: noFoods, today: today, locale: german))
        #expect(action.quantity == 1_000_000)
        // With no locale, the form reads the text as Android does.
        #expect(form.action(products: [], areas: [StorageArea.fridge], foods: noFoods, today: today)?.quantity == 1_000)

        let batch = Batch(id: "b", productId: "p", quantity: 1_000_500, storageAreaId: "fridge", dateAdded: today, expiry: nil)
        let batchForm = BatchForm.of(batch, locale: german)
        #expect(batchForm.quantity == "1000,5")
        #expect(batchForm.quantityError(locale: german) == nil)
    }
}
