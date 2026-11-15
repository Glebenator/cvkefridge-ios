import Foundation

// The suggestions of the add form.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/FoodSuggestions.kt` in cvkefridge-android has the same
// behaviour.

/// A name that the add form suggests while the person types.
public enum Suggestion: Hashable, Sendable {
    /// A product that is in the inventory. The form then adds a batch to it.
    case ofProduct(Product)
    /// A food of the table of foods. The form then has an expiry estimate. `alias` is the alias of the food that
    /// agrees with the text, when the name does not. The list shows it next to the name, so that "Cheese" for "ca"
    /// shows why: "camembert".
    case ofFood(Food, alias: String?)
}

/// Finds products and foods for the text in the name field, and connects a name to a food.
public enum FoodSuggestions {
    /// The largest number of products in one list of suggestions.
    private static let maxProducts = 2

    /// The largest number of foods with the same name in one list of suggestions, for example two kinds of ham.
    private static let maxSameName = 2

    /// The shortest text that can agree with a word that has one wrong letter.
    private static let minTypoLength = 4

    /// The words of a text in lowercase. A character that is not a letter or a number separates two words.
    static func words(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
    }

    /// How well a text agrees with a food or a product. A smaller `rank` is better. `alias` is the alias that agrees,
    /// when the name does not.
    private struct Match {
        let rank: Int
        var alias: String? = nil
    }

    /// How well the `text` agrees with a name, its aliases, and its keywords, or nil for no agreement. The name comes
    /// before an alias, because the list shows the name:
    /// 0. the name or an alias is the text;
    /// 1. the name starts with the text;
    /// 2. an alias starts with the text;
    /// 3. a word of the name starts with the text;
    /// 4. a word of an alias starts with the text;
    /// 5. a keyword starts with the text;
    /// 6. a word of the name, of an alias, or of a keyword is the text, or starts with it, with one letter that is
    ///    wrong, added, missing, or in the wrong order. Only for a text of 4 or more characters.
    private static func rank(_ text: String, name: String, aliases: [String], keywords: [String]) -> Match? {
        let lowName = name.lowercased()
        let nameWords = words(lowName)
        if lowName == text {
            return Match(rank: 0)
        }
        if let alias = aliases.first(where: { $0 == text }) {
            return Match(rank: 0, alias: alias)
        }
        if lowName.hasPrefix(text) {
            return Match(rank: 1)
        }
        if let alias = aliases.first(where: { $0.hasPrefix(text) }) {
            return Match(rank: 2, alias: alias)
        }
        if nameWords.contains(where: { $0.hasPrefix(text) }) {
            return Match(rank: 3)
        }
        if let alias = aliases.first(where: { alias in words(alias).contains(where: { $0.hasPrefix(text) }) }) {
            return Match(rank: 4, alias: alias)
        }
        if keywords.contains(where: { $0.lowercased().hasPrefix(text) }) {
            return Match(rank: 5)
        }
        if text.count < minTypoLength || text.contains(" ") {
            return nil
        }
        if (nameWords + keywords.flatMap(words)).contains(where: { closeTo(text, $0) }) {
            return Match(rank: 6)
        }
        if let alias = aliases.first(where: { alias in words(alias).contains(where: { closeTo(text, $0) }) }) {
            return Match(rank: 6, alias: alias)
        }
        return nil
    }

    /// True when the `word`, or its start, has one change from the `text`.
    private static func closeTo(_ text: String, _ word: String) -> Bool {
        changes(text, word) <= 1 || (word.count > text.count && changes(text, String(word.prefix(text.count))) <= 1)
    }

    /// The number of letters to add, remove, change, or swap with the next letter to make `second` from `first`.
    /// A result of 2 means 2 or more.
    static func changes(_ first: String, _ second: String) -> Int {
        let a = Array(first)
        let b = Array(second)
        if abs(a.count - b.count) > 1 {
            return 2
        }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count {
            d[i][0] = i
        }
        for j in 0...b.count {
            d[0][j] = j
        }
        if a.isEmpty || b.isEmpty {
            return d[a.count][b.count]
        }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
                }
            }
        }
        return d[a.count][b.count]
    }

    /// The suggestions for the `query`: first the products, then the foods of the table. A better agreement comes
    /// first. With the same agreement, a food of a product that the person had comes first, then a common food, and
    /// then the order of the table. Not more than 2 foods have the same name. The result is empty for a text of fewer
    /// than 2 characters. The result has not more than `limit` suggestions.
    public static func find(_ query: String, products: [Product], foods: FoodTable, limit: Int = 4) -> [Suggestion] {
        let text = Names.clean(query).lowercased()
        if text.count < 2 || limit <= 0 {
            return []
        }

        let foundProducts = products.enumerated()
            .compactMap { offset, product -> (rank: Int, offset: Int, product: Product)? in
                guard let match = rank(text, name: product.name, aliases: [], keywords: []) else {
                    return nil
                }
                return (match.rank, offset, product)
            }
            .sorted(by: { first, second in
                if first.rank != second.rank {
                    return first.rank < second.rank
                }
                let names = Names.order(first.product.name, second.product.name)
                if names != .orderedSame {
                    return names == .orderedAscending
                }
                if first.product.id != second.product.id {
                    return first.product.id.utf8.lexicographicallyPrecedes(second.product.id.utf8)
                }
                return first.offset < second.offset
            })
            .prefix(min(maxProducts, limit))
            .map(\.product)

        // A food that a suggested product already has is not in the list a second time.
        let taken = Set(foundProducts.compactMap(\.foodId))
        let known = Set(products.compactMap(\.foodId))
        let ranked = foods.foods.enumerated()
            .filter { !taken.contains($0.element.id) }
            .compactMap { offset, food -> (match: Match, offset: Int, food: Food)? in
                guard let match = rank(text, name: food.name, aliases: food.aliases, keywords: food.keywords) else {
                    return nil
                }
                return (match, offset, food)
            }
            .sorted(by: { first, second in
                if first.match.rank != second.match.rank {
                    return first.match.rank < second.match.rank
                }
                let firstKnown = known.contains(first.food.id)
                let secondKnown = known.contains(second.food.id)
                if firstKnown != secondKnown {
                    return firstKnown
                }
                if first.food.common != second.food.common {
                    return first.food.common
                }
                return first.offset < second.offset
            })
        var perName: [String: Int] = [:]
        var foundFoods: [Suggestion] = []
        let foodLimit = limit - foundProducts.count
        for item in ranked where foundFoods.count < foodLimit {
            let key = item.food.name.lowercased()
            let count = perName[key, default: 0]
            perName[key] = count + 1
            if count < maxSameName {
                foundFoods.append(.ofFood(item.food, alias: item.match.alias))
            }
        }
        return foundProducts.map { Suggestion.ofProduct($0) } + foundFoods
    }

    /// The food with this name, when exactly one food of the table has it as its name or as an alias. Case has no
    /// effect. "Yoghurt" gets the food "Yogurt".
    public static func onlyFoodNamed(_ name: String, foods: FoodTable) -> Food? {
        let found = foods.foods.filter { food in
            Names.same(food.name, name) || food.aliases.contains(where: { Names.same($0, name) })
        }
        return found.count == 1 ? found[0] : nil
    }

    /// True when the `name` can be a name for the `food`: a word of the name is a word of the name of the food, of an
    /// alias, or of a keyword. "Cheddar" fits the food "Cheese" with the keyword "cheddar". "Bread" does not fit
    /// "Milk".
    public static func fits(_ food: Food, name: String) -> Bool {
        let known = Set(words(food.name) + food.aliases.flatMap(words) + food.keywords.flatMap(words))
        return words(name).contains(where: { known.contains($0) })
    }
}
