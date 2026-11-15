import CVKEFridgeFeatures
import Testing

/// The values of the add form from a looked-up product: the name, the category, the food of the table of foods, and
/// the quantity of the package. The foods here have the names, the categories, and the keywords of `spec/foods.json`.
/// The Android test `ProductMappingTest` has the same cases. The last tests are for the corrections of the iOS port.
struct ProductMappingTests {
    /// `Names.MAX_FOOD_LENGTH` of Android.
    private static let maxNameLength = 80

    /// `StorageTexts.clean` of Android, until the inventory rules of the iOS port give it: one space between words, no
    /// spaces at the ends, and not more than 500 characters.
    private static func cleanStorageText(_ text: String?) -> String? {
        let plain = (text ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return plain.isEmpty ? nil : String(plain.prefix(500))
    }

    private func food(
        _ id: String,
        _ name: String,
        _ subtitle: String?,
        _ category: CVKEFridgeCore.Category,
        _ keywords: String...
    ) -> Food {
        Food(id: id, name: name, subtitle: subtitle, category: category, keywords: keywords, days: [.fridge: 7])
    }

    private var foods: FoodTable {
        FoodTable(foods: [
            food("fk-1", "Butter", nil, .dairy, "butter"),
            food("fk-3", "Cheese", "hard such as cheddar, swiss, block parmesan", .dairy, "cheese", "cheddar", "swiss", "parmesan"),
            food("fk-4", "Cheese", "parmesan; shredded or grated", .dairy, "cheese", "parmesan", "shredded", "grated"),
            food("fk-7", "Cheese", "soft such as brie, bel paese, goat", .dairy, "cheese", "brie", "bel paese", "goat"),
            food("fk-21", "Eggs", "in shell", .dairy, "eggs", "in shell", "egg", "shell"),
            food("fk-23", "Eggs", "hard boiled cooked", .dairy, "eggs", "egg", "hard boiled cooked", "boiled", "hard boiled"),
            food("fk-27", "Milk", "plain or flavored", .dairy, "milk", "plain", "flavored", "flavor"),
            food("fk-33", "Yogurt", nil, .dairy, "yogurt"),
            food("fk-113", "Chicken", "whole", .meat, "chicken", "whole"),
            food("fk-118", "Chicken parts", "legs or thighs", .meat, "chicken parts", "legs", "thighs", "chicken", "leg", "thigh"),
            food("fk-216", "Chocolate", "unsweetened and semi-sweet, solid", .other, "chocolate"),
            food("fk-383", "Milk", "canned evaporated or condensed", .other, "milk", "canned"),
            food("fk-387", "Peanut butter", "commercial", .other, "peanut butter", "commercial"),
        ])
    }

    private let hints = StorageHints(
        afterOpening: ["after opening"],
        tags: [.freezer: ["en:frozen-pizzas"], .fridge: ["en:yogurts"]]
    )

    private func product(
        _ name: String,
        brands: String? = nil,
        quantity: String? = nil,
        categories: [String] = [],
        storageText: String? = nil
    ) -> LookedUpProduct {
        LookedUpProduct(name: name, brands: brands, quantity: quantity, categories: categories, storageText: storageText)
    }

    private func name(_ product: LookedUpProduct) -> String {
        ProductNames.of(product, maxLength: Self.maxNameLength)
    }

    private func found(_ barcode: String, _ product: LookedUpProduct) -> Scanned {
        ScannedFoods.found(
            barcode: barcode,
            product: product,
            foods: foods,
            hints: hints,
            maxNameLength: Self.maxNameLength,
            cleanStorageText: Self.cleanStorageText
        )
    }

    @Test func theNameHasTheBrandOnlyWhenTheNameDoesNotHaveIt() {
        #expect(name(product("Nutella", brands: "Ferrero, Nutella")) == "Nutella")
        #expect(name(product("Coca-Cola", brands: "COCA-COLA SERVICES SA/NV")) == "Coca-Cola")
        #expect(name(product("Greek Yogurt", brands: "Fage")) == "Fage Greek Yogurt")
        #expect(name(product("Greek Yogurt", brands: " , ")) == "Greek Yogurt")
    }

    @Test func aMessyNameBecomesACleanName() {
        // Tabs, line breaks, and spaces become one space. HTML entities become their characters. Capital letters
        // only get a capital letter at the start of each word.
        #expect(
            name(product("GREEK  STYLE\tYOGURT\n", brands: " ,  BIO&amp;GUT  , Hofmolkerei"))
                == "Bio&Gut Greek Style Yogurt"
        )
        #expect(name(product("Ben &quot;n&quot; Jerry's Cookie Dough")) == "Ben \"n\" Jerry's Cookie Dough")
        // A name with small letters stays as it is. A name of three capital letters or fewer stays also: it can be an
        // abbreviation.
        #expect(name(product("UHT Milk")) == "UHT Milk")
        #expect(name(product("BBQ")) == "BBQ")
    }

    @Test func aLongNameLosesTheBrandAndThenTheWordsAtTheEnd() {
        let long = "Organic wholegrain sourdough bread with sunflower seeds, pumpkin seeds and linseed"
        #expect(long.count == 82)
        #expect(
            name(product(long, brands: "Baker"))
                == "Organic wholegrain sourdough bread with sunflower seeds, pumpkin seeds and"
        )
        let shorter = "Organic wholegrain sourdough bread with sunflower seeds and pumpkin seeds"
        #expect(name(product(shorter, brands: "The Village Bakery of Somewhere")) == shorter)
        #expect(name(product(String(repeating: "a", count: 95))) == String(repeating: "a", count: 80))
    }

    @Test func theCategoryComesFromWholeTagsInAFixedOrder() {
        #expect(ProductCategories.of(["en:breakfasts", "en:spreads", "en:sweet-spreads"]) == .condiment)
        #expect(ProductCategories.of(["en:beverages", "en:sodas", "en:colas"]) == .beverage)
        // A drinking yoghurt is a dairy, not a beverage.
        #expect(ProductCategories.of(["en:dairies", "en:yogurts", "en:beverages"]) == .dairy)
        #expect(ProductCategories.of(["en:fishes", "en:fatty-fishes"]) == .meat)
        #expect(ProductCategories.of(["EN:Breads"]) == .bakery)
        #expect(ProductCategories.of(["en:plant-based-foods", "en:fruits", "en:apples"]) == .produce)
        // A part of a tag does not match: a meat analogue is not meat.
        #expect(ProductCategories.of(["en:meat-analogues", "en:meat-alternatives", "en:plant-based-foods"]) == nil)
        #expect(ProductCategories.of(["fr:pates-a-tartiner"]) == nil)
        #expect(ProductCategories.of([]) == nil)
    }

    @Test func aFoodMatchesWhenEachWordOfItsNameIsInTheProductName() {
        #expect(FoodMatch.find("Greek Style Yogurt", category: .dairy, foods: foods)?.id == "fk-33")
        #expect(FoodMatch.find("Salted Butter", category: .dairy, foods: foods)?.id == "fk-1")
        // The food with more words wins.
        #expect(FoodMatch.find("Smooth Peanut Butter", category: nil, foods: foods)?.id == "fk-387")
        // A word with "s" at the end is the same word.
        #expect(FoodMatch.find("Free range egg", category: .dairy, foods: foods)?.id == "fk-21")
        // A part of a word does not match.
        #expect(FoodMatch.find("Buttermilk pancakes", category: nil, foods: foods) == nil)
    }

    @Test func theCategoryOfTheTagsLimitsTheFoods() {
        // The milk of the dairy category, not the canned milk.
        #expect(FoodMatch.find("Whole Milk", category: .dairy, foods: foods)?.id == "fk-27")
        // Peanut butter is "other" in the table, so a spread does not get it.
        #expect(FoodMatch.find("Smooth Peanut Butter", category: .condiment, foods: foods) == nil)
    }

    @Test func twoDifferentFoodsInTheNameGiveNoFood() {
        #expect(FoodMatch.find("Milk Chocolate", category: nil, foods: foods) == nil)
        #expect(FoodMatch.find("Butter Chicken", category: nil, foods: foods) == nil)
        #expect(FoodMatch.find("Cocoa", category: nil, foods: foods) == nil)
        #expect(FoodMatch.find("", category: nil, foods: foods) == nil)
    }

    @Test func theKeywordsChooseBetweenFoodsWithTheSameName() {
        #expect(FoodMatch.find("Grated Parmesan Cheese", category: .dairy, foods: foods)?.id == "fk-4")
        #expect(FoodMatch.find("French Brie Cheese", category: .dairy, foods: foods)?.id == "fk-7")
        // No keyword decides: the first food of the name in the table.
        #expect(FoodMatch.find("Cheese", category: .dairy, foods: foods)?.id == "fk-3")
        #expect(FoodMatch.find("Large Eggs", category: .dairy, foods: foods)?.id == "fk-21")
    }

    @Test func theQuantityOfAPackageIsReadOnlyWhenItIsReliable() {
        #expect(PackQuantity.parse("400 g e") == .init(quantity: 400_000, unit: .g))
        #expect(PackQuantity.parse("400 g ℮") == .init(quantity: 400_000, unit: .g))
        #expect(PackQuantity.parse("500g") == .init(quantity: 500_000, unit: .g))
        #expect(PackQuantity.parse("250 gr.") == .init(quantity: 250_000, unit: .g))
        #expect(PackQuantity.parse("1,5 L") == .init(quantity: 1_500, unit: .l))
        #expect(PackQuantity.parse(" 1 kg ") == .init(quantity: 1_000, unit: .kg))
        #expect(PackQuantity.parse("330 ml") == .init(quantity: 330_000, unit: .ml))
        #expect(PackQuantity.parse("70 cl") == .init(quantity: 700_000, unit: .ml))
        #expect(PackQuantity.parse("2 dl") == .init(quantity: 200_000, unit: .ml))
        #expect(PackQuantity.parse("6 x 150 g") == nil)
        #expect(PackQuantity.parse("144 fl oz") == nil)
        #expect(PackQuantity.parse("1.000 g") == nil)
        #expect(PackQuantity.parse("0 g") == nil)
        #expect(PackQuantity.parse("100000 g") == nil)
        #expect(PackQuantity.parse("12 eggs") == nil)
        #expect(PackQuantity.parse("") == nil)
    }

    @Test func aFoundProductGivesTheValuesOfTheForm() {
        #expect(
            found("3017620422003", product("Nutella", brands: "Ferrero, Nutella", quantity: "400 g e", categories: ["en:spreads"]))
                == Scanned(
                    barcode: "3017620422003", source: .found, name: "Nutella", category: .condiment, foodId: nil,
                    quantity: 400_000, unit: .g
                )
        )
        let messy = product(
            "GREEK  STYLE\tYOGURT\n",
            brands: " ,  BIO&amp;GUT  , Hofmolkerei",
            quantity: "6 x 150 g",
            categories: ["en:dairies", "en:yogurts", "en:beverages"]
        )
        #expect(
            found("4006381333931", messy)
                == Scanned(
                    barcode: "4006381333931", source: .found, name: "Bio&Gut Greek Style Yogurt", category: .dairy,
                    foodId: "fk-33", quantity: nil, unit: nil, storageKind: .fridge
                )
        )
        // With no tags, the food gives the category.
        #expect(found("1", product("Whole milk")).category == .dairy)
        #expect(found("1", product("Mystery snack")).category == nil)
    }

    @Test func aFoundProductGetsTheStorageKindOfItsStorageHint() {
        func kind(_ product: LookedUpProduct) -> StorageKind? {
            found("1", product).storageKind
        }
        // The name has no food of the table. The tags give the freezer.
        #expect(kind(product("Ristorante Mozzarella", categories: ["en:meals", "en:frozen-pizzas"])) == .freezer)
        // The storage text comes before the tags.
        #expect(kind(product("Pizza dough", categories: ["en:frozen-pizzas"], storageText: "Keep at +4°C")) == .fridge)
        #expect(kind(product("Peas", storageText: "Bei -18 °C mindestens haltbar bis: siehe Seite")) == .freezer)
        // A product with no hint has no storage kind. The food of its name gives the storage area later, in the form.
        #expect(kind(product("Whole milk", categories: ["en:dairies"], storageText: "After opening keep at 7°C")) == nil)
        // The scan keeps the storage text in the form that the app saves.
        #expect(found("1", product("Peas", storageText: " Bei -18 °C\nlagern. ")).storageText == "Bei -18 °C lagern.")
    }

    @Test func aBarcodeOfAProductInTheInventoryFindsTheProduct() {
        let upcA = Product(id: "p-1", name: "Cola", category: .beverage, unit: nil, barcode: "036000291452", foodId: nil)
        let ean = Product(id: "p-2", name: "Water", category: .beverage, unit: nil, barcode: "5449000000996", foodId: nil)
        let none = Product(id: "p-3", name: "Rice", category: .other, unit: nil, barcode: nil, foodId: nil)
        let products = [none, upcA, ean]
        #expect(ScannedFoods.productWithBarcode(products, barcode: "0036000291452") == upcA)
        #expect(ScannedFoods.productWithBarcode(products, barcode: "5449000000996") == ean)
        #expect(ScannedFoods.productWithBarcode(products, barcode: "3017620422003") == nil)
    }

    // Correction of ProductMapping.kt:37: the entities were replaced one after the other, so "&amp;lt;" became "<".
    @Test func anEntityIsReadOneTime() {
        #expect(name(product("Salt &amp;lt; 1 g")) == "Salt &lt; 1 g")
        #expect(name(product("Fish &amp; Chips &#39;n&#39; Peas")) == "Fish & Chips 'n' Peas")
        #expect(name(product("A & B &unknown;")) == "A & B &unknown;")
    }

    // Correction of ProductMapping.kt:46: a letter after an apostrophe started a word, so "JERRY'S" became "Jerry'S".
    @Test func aLetterAfterAnApostropheInAWordStaysSmall() {
        #expect(name(product("BEN & JERRY'S COOKIE DOUGH")) == "Ben & Jerry's Cookie Dough")
        #expect(name(product("DON’T PANIC")) == "Don’t Panic")
        // One letter before the apostrophe is a part of a name: the letter after it starts a word.
        #expect(name(product("L’OR ESPRESSO")) == "L’Or Espresso")
        #expect(name(product("O'BRIEN'S STEW")) == "O'Brien's Stew")
        #expect(name(product("'TIS THE SEASON")) == "'Tis The Season")
    }
}
