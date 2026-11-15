import Testing
@testable import CVKEFridgeFeatures

/// The rules for names and notes, and the form of a storage area. Android has no test file for them: its other tests
/// use them. These cases also cover the corrections of the iOS app.
struct NamesTests {
    @Test func aCleanNameHasOneSpaceBetweenWords() {
        #expect(Names.clean("  Whole \t milk \n") == "Whole milk")
        #expect(Names.clean("   ") == "")
        // A no-break space is a space. Android keeps it, so the two names below were different products.
        #expect(Names.clean("Whole\u{00A0}milk") == "Whole milk")
        #expect(Names.same("Whole\u{00A0}milk", "whole MILK"))
        #expect(!Names.same("Milk", "Silk"))
    }

    // Kotlin `equals(ignoreCase = true)` changes each character to upper case and then to lower case. Swift
    // `lowercased()` does not make "Σ" and the final "ς" the same.
    @Test func theSameNameHasTheCaseRuleOfKotlin() {
        #expect(Names.same("ΟΔΟΣ", "οδος"))
        #expect(Names.same("οδοσ", "οδος"))
        #expect(Names.same("İstanbul", "istanbul"))
        #expect(Names.same("ÆBLE", "æble"))
        #expect(Names.same("\u{01C5}emal", "\u{01C6}EMAL"))
        #expect(Names.same("Straße", "STRAẞE"))
        // A character that has more than one character in upper case is not the same as those characters.
        #expect(!Names.same("Straße", "STRASSE"))
        // Accents have an effect on the name, but not on the order.
        #expect(!Names.same("Éclair", "Eclair"))
        #expect(Names.order("Éclair", "eclair") == .orderedSame)
        // A decomposed accent is the same as the composed accent.
        #expect(Names.same("Cre\u{0300}me", "CRÈME"))
        #expect(Names.key(" Whole   MILK ") == "whole milk")
        // The forms find a product and a food with this rule.
        let food = Food(id: "f", name: "Οδος", subtitle: nil, category: .other, keywords: [], days: [:], aliases: ["σκορδοσ"])
        #expect(FoodSuggestions.onlyFoodNamed("ΣΚΟΡΔΟΣ", foods: FoodTable(foods: [food]))?.id == "f")
        #expect(FoodSuggestions.onlyFoodNamed("σκορδος", foods: FoodTable(foods: [food]))?.id == "f")
    }

    @Test func theOrderOfNamesHasNoEffectFromCaseOrAccents() {
        #expect(Names.order("apple", "Banana") == .orderedAscending)
        #expect(Names.order("Banana", "apple") == .orderedDescending)
        #expect(Names.order("Milk", "milk") == .orderedSame)
        // Android puts "Éclair" after "Zucchini".
        #expect(Names.order("Éclair", "Zucchini") == .orderedAscending)
        #expect(Names.order("Crème", "Crepe") == .orderedAscending)
        #expect(Names.order("Crème", "creme") == .orderedSame)
    }

    @Test func aNoteIsCleanedAtTheEndsOnly() {
        #expect(Notes.clean("  For the cake,\nnot for toast \n") == "For the cake,\nnot for toast")
        #expect(Notes.clean(" \n ") == nil)
    }

    @Test func aStorageAreaFormChecksTheName() {
        let cellar = StorageArea(id: "cellar", name: "Cellar", kind: .pantry, fixed: false)
        let areas = [StorageArea.fridge, StorageArea.freezer, cellar]
        let new = StorageAreaForm.of(nil)
        #expect(new == StorageAreaForm(id: nil, name: "", kind: .pantry))
        #expect(new.nameError(areas: areas) == .empty)
        #expect(new.action(areas: areas) == nil)

        var named = new
        named.name = " fridge "
        #expect(named.nameError(areas: areas) == .inUse)
        named.name = String(repeating: "a", count: Names.maxAreaLength + 1)
        #expect(named.nameError(areas: areas) == .tooLong)
        named.name = "  Garage   fridge "
        named.kind = .fridge
        #expect(named.action(areas: areas) == InventoryAction.SaveStorageArea(id: nil, name: "Garage fridge", kind: .fridge))

        // The area keeps its own name.
        var edit = StorageAreaForm.of(cellar)
        edit.name = "CELLAR"
        #expect(edit.action(areas: areas) == InventoryAction.SaveStorageArea(id: "cellar", name: "CELLAR", kind: .pantry))
    }
}
