import Foundation

// The rules that change a product of Open Food Facts into the values of the add form. The Android file
// `app/src/main/java/com/cvke/fridge/lookup/ProductMapping.kt` in cvkefridge-android has the same behaviour, with two
// corrections (HTML entities are read one time, and a letter after an apostrophe in a word does not start a
// word).
//
// The shared specification has no rules for this yet. Each rule compares whole words or whole tags, never a part of a
// word (section 2 of the plan in the cvkefridge repository). A length is a number of characters (`Character`).

/// The name of a looked-up product for the inventory.
public enum ProductNames {
    /// The brand and the product name, for example "Ferrero Nutella". The brand is not added when the name already
    /// has the first word of one of the brands ("Coca-Cola Original" from "COCA-COLA SERVICES SA/NV"). A text in
    /// capital letters only gets a capital letter at the start of each word. The result has not more than `maxLength`
    /// characters: a longer name loses the brand, and then the words at the end.
    ///
    /// The name is clean as the add form cleans a name (`Names.clean`): all white space between two words is one space.
    ///
    /// - Parameter maxLength: The largest number of characters in the name of a food. The add form has this limit
    ///   (`Names.maxFoodLength`).
    public static func of(_ product: LookedUpProduct, maxLength: Int = Names.maxFoodLength) -> String {
        let name = clean(product.name)
        let brands = (product.brands ?? "").split(separator: ",", omittingEmptySubsequences: false)
            .map { clean(String($0)) }
            .filter { !$0.isEmpty }
        let nameWords = Set(FoodMatch.words(name))
        let brandInName = brands.contains { brand in
            FoodMatch.words(brand).first.map { nameWords.contains($0) } ?? false
        }
        var chosen = name
        if let brand = brands.first, !brandInName {
            let withBrand = "\(brand) \(name)"
            if withBrand.count <= maxLength {
                chosen = withBrand
            }
        }
        return shorten(chosen, maxLength: maxLength)
    }

    private static let entities: [String: String] = [
        "&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">",
    ]

    private static func clean(_ text: String) -> String {
        // A tab or a line break between two words is a space.
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            scalars.append(isISOControl(scalar) ? " " : scalar)
        }
        let plain = Names.clean(decodeEntities(String(scalars)))
        let letters = plain.filter(\.isLetter)
        let hasLowercase = letters.contains(where: \.isLowercase)
        return letters.count > 3 && !hasLowercase ? capitalizeWords(plain) : plain
    }

    /// Replaces each entity of `entities` with its character, in one pass from the start: "&amp;lt;" becomes "&lt;".
    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else {
            return text
        }
        var result = ""
        var rest = Substring(text)
        while let ampersand = rest.firstIndex(of: "&") {
            result += rest[rest.startIndex..<ampersand]
            let tail = rest[ampersand...]
            if let (entity, character) = entities.first(where: { tail.hasPrefix($0.key) }) {
                result += character
                rest = tail.dropFirst(entity.count)
            } else {
                result += "&"
                rest = tail.dropFirst()
            }
        }
        return result + rest
    }

    /// "COCA-COLA ZERO" becomes "Coca-Cola Zero", "JERRY'S" becomes "Jerry's", and "O'BRIEN" becomes "O'Brien".
    private static func capitalizeWords(_ text: String) -> String {
        let characters = Array(text)
        var result = ""
        for (index, character) in characters.enumerated() {
            var startsWord = index == 0 || !characters[index - 1].isLetter
            // A letter after an apostrophe does not start a word when two or more letters come before the
            // apostrophe: "Jerry's" and "Don't", but "O'Brien" and "L'Or".
            if index >= 3, isApostrophe(characters[index - 1]), characters[index - 2].isLetter,
               characters[index - 3].isLetter {
                startsWord = false
            }
            result += startsWord ? titlecased(character) : character.lowercased()
        }
        return result
    }

    private static func isApostrophe(_ character: Character) -> Bool {
        character == "'" || character == "\u{2019}"
    }

    private static func titlecased(_ character: Character) -> String {
        var scalars = character.unicodeScalars.makeIterator()
        guard let first = scalars.next() else {
            return String(character)
        }
        var rest = String.UnicodeScalarView()
        while let scalar = scalars.next() {
            rest.append(scalar)
        }
        return first.properties.titlecaseMapping + String(rest).lowercased()
    }

    /// The text cut after the last whole word that fits, or after `maxLength` characters.
    private static func shorten(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        let head = text.prefix(maxLength + 1)
        var cut = maxLength
        if let space = head.lastIndex(of: " "), space > head.startIndex {
            cut = head.distance(from: head.startIndex, to: space)
        }
        return trimEnd(String(text.prefix(cut)))
    }

    private static func trimEnd(_ text: String) -> String {
        var result = Substring(text)
        while let last = result.last, last.isWhitespace {
            result = result.dropLast()
        }
        return String(result)
    }
}

/// The category of a looked-up product from its category tags. A rule matches a whole tag of the taxonomy of Open
/// Food Facts. The tags of a product include the parent categories, so a few general tags are sufficient. The rules
/// apply in this order, and the first category that matches is the result: dairy, meat, beverage, bakery, condiment,
/// produce. A drinking yoghurt is then dairy, and a fruit juice is a beverage.
public enum ProductCategories {
    private static let rules: [(CVKEFridgeCore.Category, Set<String>)] = [
        (.dairy, ["en:dairies", "en:eggs"]),
        (.meat, ["en:meats", "en:poultries", "en:fishes", "en:seafood"]),
        (.beverage, ["en:beverages"]),
        (.bakery, ["en:breads", "en:biscuits-and-cakes", "en:pastries", "en:viennoiseries"]),
        (.condiment, ["en:condiments", "en:sauces", "en:spreads"]),
        (.produce, ["en:fruits", "en:vegetables", "en:fruits-based-foods", "en:vegetables-based-foods"]),
    ]

    /// The category of the tags, or nil when no rule matches. Case has no effect.
    public static func of(_ tags: [String]) -> CVKEFridgeCore.Category? {
        let all = Set(tags.map { $0.lowercased() })
        return rules.first(where: { !$0.1.isDisjoint(with: all) })?.0
    }
}

/// Finds the food of the table of foods that a product name clearly names, for the expiry estimate.
///
/// 1. A food is a candidate when each word of its name is a word of the product name. A word with an "s" at the end
///    is the same as the word without it ("Eggs" and "egg").
/// 2. When the category tags give a category, only the foods of that category are candidates. "Milk chocolate" is
///    then not milk.
/// 3. The candidates with the most words in their name stay ("Peanut butter" before "Butter").
/// 4. When these candidates have different names, the name is not clear, and there is no food.
/// 5. When they have the same name, the food with the most other words of the product name in its subtitle and its
///    keywords is the result. With equal numbers, the first food in the table, which is the usual form of the food.
public enum FoodMatch {
    /// The words of a text in lower case. A word is a sequence of letters and digits (Unicode categories L and N).
    public static func words(_ text: String) -> [String] {
        var result: [String] = []
        var current = String.UnicodeScalarView()
        for scalar in text.lowercased().unicodeScalars {
            if isWordScalar(scalar) {
                current.append(scalar)
            } else if !current.isEmpty {
                result.append(String(current))
                current = String.UnicodeScalarView()
            }
        }
        if !current.isEmpty {
            result.append(String(current))
        }
        return result
    }

    /// The food of the table that the product name clearly names, or nil.
    public static func find(_ productName: String, category: CVKEFridgeCore.Category?, foods: FoodTable) -> Food? {
        let words = stems(productName)
        if words.isEmpty {
            return nil
        }
        let candidates = foods.foods.filter { food in
            let nameWords = stems(food.name)
            return (category == nil || food.category == category) && !nameWords.isEmpty && nameWords.isSubset(of: words)
        }
        guard let most = candidates.map({ stems($0.name).count }).max() else {
            return nil
        }
        let best = candidates.filter { stems($0.name).count == most }
        if Set(best.map { Names.clean($0.name).lowercased() }).count > 1 {
            return nil
        }
        // The first food with the highest number.
        var result: Food?
        var highest = -1
        for food in best {
            var other = Set((food.keywords + (food.subtitle.map { [$0] } ?? [])).flatMap { stems($0) })
            other.subtract(stems(food.name))
            let count = other.filter { words.contains($0) }.count
            if count > highest {
                highest = count
                result = food
            }
        }
        return result
    }

    private static func stem(_ word: String) -> String {
        if word.count > 3 && word.hasSuffix("s") && !word.hasSuffix("ss") {
            return String(word.dropLast())
        }
        return word
    }

    private static func stems(_ text: String) -> Set<String> {
        Set(words(text).map(stem))
    }

    private static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            return true
        default:
            return false
        }
    }
}

/// The quantity of a package, from its text on Open Food Facts.
public enum PackQuantity {
    /// A quantity in thousandths and its unit.
    public struct Value: Hashable, Sendable {
        public let quantity: Int
        public let unit: MeasureUnit

        public init(quantity: Int, unit: MeasureUnit) {
            self.quantity = quantity
            self.unit = unit
        }
    }

    /// The largest quantity of a form: 99999.999.
    private static let maxThousandths = 99_999_999

    /// The units of the text in lowercase, in the order of the Kotlin pattern, with the factor and the unit.
    private static let units: [(text: String, factor: Int, unit: MeasureUnit)] = [
        ("kg", 1, .kg), ("g", 1, .g), ("gr", 1, .g), ("ml", 1, .ml), ("cl", 10, .ml), ("dl", 100, .ml),
        ("l", 1, .l), ("lt", 1, .l),
    ]

    /// The quantity in thousandths and the unit, when the text is one number and one unit of weight or volume, for
    /// example "400 g", "1,5 L", or "70 cl" (700 ml). Other texts are not reliable, and the result is nil: more than
    /// one package ("6 x 330 ml"), other units ("12 oz"), and numbers with 3 decimals ("1.000 g" can be 1 g or
    /// 1000 g). The pattern is `^(\d{1,5})(?:[.,](\d{1,2}))?\s*(kg|g|gr|ml|cl|dl|l|lt)\.?(?:\s*[e℮])?$` with ASCII
    /// digits and spaces, and no difference between capital and small ASCII letters.
    public static func parse(_ text: String) -> Value? {
        let scalars = Array(text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars)
        var at = 0
        let whole = digits(scalars, from: &at)
        guard (1...5).contains(whole.count) else {
            return nil
        }
        var fraction: [Int] = []
        if at < scalars.count, scalars[at] == "." || scalars[at] == "," {
            at += 1
            fraction = digits(scalars, from: &at)
            guard (1...2).contains(fraction.count) else {
                return nil
            }
        }
        while at < scalars.count, isSpace(scalars[at]) {
            at += 1
        }
        let rest = Array(scalars[at...])
        for candidate in units {
            let unitScalars = Array(candidate.text.unicodeScalars)
            guard rest.count >= unitScalars.count,
                  zip(rest, unitScalars).allSatisfy({ lowerASCII($0) == $1 }),
                  isEnd(Array(rest[unitScalars.count...]))
            else {
                continue
            }
            var thousandths = whole.reduce(0) { $0 * 10 + $1 } * 1000
            for (index, digit) in fraction.enumerated() {
                thousandths += digit * (index == 0 ? 100 : 10)
            }
            thousandths *= candidate.factor
            guard thousandths > 0, thousandths <= maxThousandths else {
                return nil
            }
            return Value(quantity: thousandths, unit: candidate.unit)
        }
        return nil
    }

    /// True when the text after the unit is `\.?(?:\s*[e℮])?` and then the end.
    private static func isEnd(_ rest: [Unicode.Scalar]) -> Bool {
        var at = 0
        if at < rest.count, rest[at] == "." {
            at += 1
        }
        if at == rest.count {
            return true
        }
        while at < rest.count, isSpace(rest[at]) {
            at += 1
        }
        guard at < rest.count, rest[at] == "e" || rest[at] == "E" || rest[at] == "\u{212E}" else {
            return false
        }
        return at + 1 == rest.count
    }

    /// The values of the ASCII digits from `at`. `at` moves after them.
    private static func digits(_ scalars: [Unicode.Scalar], from at: inout Int) -> [Int] {
        var values: [Int] = []
        while at < scalars.count, scalars[at].value >= 0x30, scalars[at].value <= 0x39 {
            values.append(Int(scalars[at].value) - 0x30)
            at += 1
        }
        return values
    }

    /// The ASCII spaces of `\s`: space, tab, line feed, vertical tab, form feed, and carriage return.
    private static func isSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || (0x09...0x0D).contains(scalar.value)
    }

    private static func lowerASCII(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        (0x41...0x5A).contains(scalar.value) ? Unicode.Scalar(scalar.value + 0x20) ?? scalar : scalar
    }
}

/// A character in the ranges U+0000 to U+001F and U+007F to U+009F.
private func isISOControl(_ scalar: Unicode.Scalar) -> Bool {
    scalar.value <= 0x1F || (0x7F...0x9F).contains(scalar.value)
}
