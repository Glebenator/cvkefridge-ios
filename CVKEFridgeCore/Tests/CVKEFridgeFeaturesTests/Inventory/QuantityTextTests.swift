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
}
