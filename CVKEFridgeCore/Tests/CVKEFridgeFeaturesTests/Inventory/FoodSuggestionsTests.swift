import Foundation
import Testing
@testable import CVKEFridgeFeatures

/// The real table of foods, `spec/foods.json`. The root of the repository is five levels above this file.
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

/// The suggestions of the add form: aliases, common foods, the foods of the person, and a wrong letter. The same
/// cases as the Android FoodSuggestionsTest.
struct FoodSuggestionsTests {
    private let table = RealFoods.table

    private func ids(_ query: String, products: [Product] = [], foods: FoodTable? = nil) -> [String] {
        FoodSuggestions.find(query, products: products, foods: foods ?? table).map { suggestion in
            switch suggestion {
            case .ofProduct(let product):
                return product.id
            case .ofFood(let food, _):
                return food.id
            }
        }
    }

    /// The foods of the suggestions, with their aliases.
    private func foods(_ query: String) -> [(food: Food, alias: String?)] {
        FoodSuggestions.find(query, products: [], foods: table).compactMap { suggestion in
            if case .ofFood(let food, let alias) = suggestion {
                return (food, alias)
            }
            return nil
        }
    }

    @Test func anAliasFindsTheFood() {
        #expect(ids("yoghurt").first == "fk-33")
        #expect(ids("mince").first == "fk-43")
        #expect(ids("courgette").first == "fk-547")
        #expect(ids("prawns").first == "fk-151")
        #expect(ids("salmon").contains("fk-146"))
    }

    @Test func aNameComesBeforeAnAliasAndTheSuggestionShowsTheAlias() throws {
        // "Cabbage" starts with "ca". "Cheese" only has the alias "camembert", so it comes after the names.
        let found = foods("ca")
        #expect(found.prefix(3).allSatisfy { $0.food.name.hasPrefix("Ca") })
        #expect(found.allSatisfy { $0.alias == nil })

        let camembert = try #require(foods("camem").first)
        #expect(camembert.food.id == "fk-7")
        #expect(camembert.alias == "camembert")
        // A name that agrees shows no alias.
        let cheese = try #require(foods("chee").first)
        #expect(cheese.alias == nil)
    }

    @Test func aCommonFoodComesBeforeTheOtherFoodsAndOnlyTwoFoodsHaveTheSameName() {
        // Plain milk, not evaporated milk.
        #expect(ids("milk").first == "fk-27")
        // Ham from the deli, not canned ham. The table has 21 kinds of ham.
        let ham = ids("ham")
        #expect(ham.first == "fk-515")
        #expect(ham.filter { table.food(id: $0)?.name == "Ham" }.count == 2)
        #expect(ids("eggs").first == "fk-21")
    }

    @Test func aFoodThatThePersonHadComesBeforeACommonFood() {
        // The person had a product that was not cheddar, with the food of soft cheese.
        let brie = Product(id: "p-brie", name: "Brie de Meaux", category: .dairy, unit: nil, barcode: nil, foodId: "fk-7")
        #expect(Array(ids("chee", products: [brie]).prefix(2)) == ["fk-7", "fk-3"])
    }

    @Test func aNameWithOneWrongLetterFindsTheFoodAfterTheFoodsWithNoWrongLetter() {
        #expect(ids("chiken").first.flatMap { table.food(id: $0)?.name } == "Chicken")
        #expect(ids("strawbery").first == "fk-481")
        #expect(ids("brocoli").contains("fk-276"))
        // Fewer than 4 characters: no wrong letter is permitted.
        #expect(ids("xgg") == [])
    }

    @Test func theChangesCountAddedMissingChangedAndSwappedLetters() {
        #expect(FoodSuggestions.changes("chiken", "chicken") == 1)
        #expect(FoodSuggestions.changes("mlik", "milk") == 1)
        #expect(FoodSuggestions.changes("bread", "breed") == 1)
        #expect(FoodSuggestions.changes("bread", "brand") == 2)
    }

    @Test func anAliasConnectsATypedNameToTheFood() throws {
        #expect(FoodSuggestions.onlyFoodNamed("Yoghurt", foods: table)?.id == "fk-33")
        let yogurt = try #require(table.food(id: "fk-33"))
        #expect(FoodSuggestions.fits(yogurt, name: "Greek yoghurt"))
        #expect(!FoodSuggestions.fits(yogurt, name: "Bread"))
    }

    @Test func theOrderOfTheTableStaysWhenNothingElseIsDifferent() {
        let a = Food(id: "a", name: "Beans", subtitle: nil, category: .other, keywords: [], days: [:])
        let b = Food(id: "b", name: "Beans", subtitle: "dried", category: .other, keywords: [], days: [:], common: true)
        let c = Food(id: "c", name: "Beetroot", subtitle: nil, category: .produce, keywords: [], days: [:])
        #expect(ids("be", foods: FoodTable(foods: [a, b, c])) == ["b", "a", "c"])
    }

    @Test func aSmallLimitGivesNotMoreSuggestions() {
        // Android stops with an error when the limit is smaller than the number of products.
        let products = [
            Product(id: "p1", name: "Butter", category: .dairy, unit: nil, barcode: nil, foodId: nil),
            Product(id: "p2", name: "Buns", category: .bakery, unit: nil, barcode: nil, foodId: nil),
        ]
        #expect(FoodSuggestions.find("bu", products: products, foods: table, limit: 1).count == 1)
        #expect(FoodSuggestions.find("bu", products: products, foods: table, limit: 0).isEmpty)
    }
}
