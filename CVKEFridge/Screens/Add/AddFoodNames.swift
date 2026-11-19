import CVKEFridgeFeatures
import SwiftUI

// The suggestions below the name field of the add form. They take the place of `Suggestions` in
// `ui/AddFoodScreen.kt` of the Android app. On iOS they are rows of the form below the name row, so they scroll with
// the form and stay above the keyboard.

/// One row of the list below the name field.
struct NameSuggestion: Identifiable, Equatable, Sendable {
    let suggestion: Suggestion
    /// True for a product with an active batch. A food of the table has false.
    let inStock: Bool

    /// The identifier of the row, also for the UI tests. The Android app has the same tags.
    var id: String {
        switch suggestion {
        case .ofProduct(let product): "suggestion_product_\(product.id)"
        case .ofFood(let food, _): "suggestion_food_\(food.id)"
        }
    }
}

/// What the list below the name field shows.
enum NameList: Equatable {
    /// No list: the name field does not have the keyboard, or there is nothing to suggest.
    case none
    /// The foods that the person added, used, or threw away last, for an empty name.
    case recent([NameSuggestion])
    /// The products and the foods of the table that agree with the name.
    case found([NameSuggestion])

    var rows: [NameSuggestion] {
        switch self {
        case .none: []
        case .recent(let rows), .found(let rows): rows
        }
    }

    var isRecent: Bool {
        if case .recent = self {
            return true
        }
        return false
    }

    /// True when the form scrolls the name to the top: the person types, and the suggestions need the room between
    /// the name and the keyboard. The recent foods of an empty name do not move the form, so that the card
    /// "Scan a barcode" above the name stays on the screen.
    var scrollsToName: Bool {
        if case .found(let rows) = self {
            return !rows.isEmpty
        }
        return false
    }
}

/// The search for the suggestions of a name.
enum NameSuggestions {
    /// The time with no new letter after which the search starts.
    static let typingPause: Duration = .milliseconds(150)

    /// The suggestions for the name of the form (`AddFoodForm.suggestions`), off the main actor. The search compares
    /// the name with each product and each food of the table, also with one wrong letter.
    @concurrent static func find(for form: AddFoodForm, inventory: Inventory, foods: FoodTable) async -> [NameSuggestion] {
        let found = form.suggestions(products: inventory.products, foods: foods)
        if found.isEmpty {
            return []
        }
        let inStock = Set(inventory.activeBatches.map(\.productId))
        return found.map { suggestion in
            if case .ofProduct(let product) = suggestion {
                return NameSuggestion(suggestion: suggestion, inStock: inStock.contains(product.id))
            }
            return NameSuggestion(suggestion: suggestion, inStock: false)
        }
    }
}

/// One suggestion, as a row of the form. A product says "In your inventory" or "You had this before". A food of the
/// table shows the text that tells it from the other foods with the same name. A food that agrees with the name by an
/// alias shows that alias after its name, in a quieter colour: "Cheese · Camembert".
///
/// A recent food has a button at the end that removes it from the list. VoiceOver also has the removal as an action
/// of the row.
struct NameSuggestionRow: View {
    let row: NameSuggestion
    let onSelect: () -> Void
    /// Removes the product with this identifier from the recent foods, or nil for a list that is not the recent
    /// foods.
    let onRemove: ((String) -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Space.s2) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(Typography.body)
                        .foregroundStyle(Palette.onSurface)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    if let detail {
                        Text(verbatim: detail)
                            .font(Typography.secondary)
                            .foregroundStyle(Palette.onSurfaceVariant)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTarget, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: spokenName))
            .accessibilityValue(Text(verbatim: detail ?? ""))
            .accessibilityHint(Text("Puts this name in the form."))
            .accessibilityIdentifier(row.id)
            .accessibilityActions {
                if let product, let onRemove {
                    Button(removeLabel(product)) { onRemove(product.id) }
                }
            }
            if let product, let onRemove {
                Button {
                    onRemove(product.id)
                } label: {
                    Image(icon: .close)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .frame(width: Metrics.minTarget, height: Metrics.minTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(verbatim: removeLabel(product)))
                .accessibilityIdentifier("recent_remove_\(product.id)")
            }
        }
        // The two buttons of the row keep their own targets. The row has no margin at the end for the button.
        .listRowInsets(EdgeInsets(top: Space.s1, leading: Space.s4, bottom: Space.s1, trailing: onRemove == nil ? Space.s4 : Space.s1))
    }

    private var product: Product? {
        if case .ofProduct(let product) = row.suggestion {
            return product
        }
        return nil
    }

    private var name: String {
        switch row.suggestion {
        case .ofProduct(let product): product.name
        case .ofFood(let food, _): food.name
        }
    }

    /// The alias of a food that agrees with the name, with a capital first letter.
    private var alias: String? {
        guard case .ofFood(_, let alias?) = row.suggestion else {
            return nil
        }
        return alias.prefix(1).capitalized + alias.dropFirst()
    }

    private var detail: String? {
        switch row.suggestion {
        case .ofProduct:
            row.inStock ? String(localized: "In your inventory") : String(localized: "You had this before")
        case .ofFood(let food, _):
            food.subtitle
        }
    }

    /// The name, and the alias after it in the muted colour.
    private var headline: AttributedString {
        var text = AttributedString(name)
        if let alias {
            var more = AttributedString(" · " + alias)
            more.foregroundColor = Palette.onSurfaceVariant
            text.append(more)
        }
        return text
    }

    private var spokenName: String {
        guard let alias else {
            return name
        }
        return String(localized: "\(name), \(alias)", comment: "For VoiceOver: a food and the alias that agrees with the typed name.")
    }

    private func removeLabel(_ product: Product) -> String {
        String(localized: "Remove \(product.name) from Recent")
    }
}
