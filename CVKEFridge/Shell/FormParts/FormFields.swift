import CVKEFridgeFeatures
import SwiftUI

// The fields that more than one form has. Each is a row of a `Form` (see `FormSheet`). They take the place of
// `QuantityField` and `SelectField` of `ui/FormParts.kt` of the Android app, with the controls of iOS: a text field
// in a row, and a menu for a list of values.

/// The quantity field: a number with the decimal keyboard of the locale. The form keeps the text, and
/// `QuantityText.parse(_:locale:)` reads it in the number format of the locale: "1,5" is 1.5 with a German locale,
/// and "1.000" is 1000. `QuantityText.format(_:locale:)` writes the text that the field shows at the start. Give the
/// same locale to the two: `Locale.current`.
///
/// ```swift
/// QuantityField(text: $form.quantity, problem: form.checked ? form.quantityError(locale: .current) : nil, unit: unitName)
/// ```
struct QuantityField: View {
    private let label: LocalizedStringKey
    @Binding private var text: String
    private let problemText: String?
    private let unit: String?

    /// - Parameters:
    ///   - problem: The problem of the text, or nil. Give it after the person selected "Save" one time.
    ///   - problemText: Words for a problem that is not a `QuantityProblem`, for example "You have only 2 l."
    ///   - unit: The unit after the number, when the person cannot change it: the unit of a product in the inventory.
    init(
        _ label: LocalizedStringKey = "Quantity",
        text: Binding<String>,
        problem: QuantityProblem?,
        problemText: String? = nil,
        unit: String? = nil
    ) {
        self.label = label
        _text = text
        self.problemText = problemText ?? problem?.message
        self.unit = unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            LabeledContent {
                HStack(spacing: Space.s1 + 2) {
                    TextField(label, text: $text, prompt: Text(verbatim: AddFoodForm.defaultQuantity))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityHint(Text(verbatim: problemText ?? ""))
                        .accessibilityIdentifier("field_quantity")
                    if let unit {
                        Text(verbatim: unit)
                            .foregroundStyle(Palette.onSurfaceVariant)
                    }
                }
            } label: {
                Text(label)
            }
            if let problemText {
                FieldProblem(problemText, identifier: "error_quantity")
            }
        }
    }
}

/// The category of a food, as a menu. The menu has words only: the system shows the selected value of a menu at the
/// size of the text, and an icon there is too large.
struct CategoryPicker: View {
    @Binding var selection: CVKEFridgeCore.Category

    var body: some View {
        Picker(selection: $selection) {
            ForEach(CVKEFridgeCore.Category.allCases, id: \.self) { category in
                Text(verbatim: category.label)
                    .tag(category)
                    .accessibilityIdentifier("category_option_\(category.rawValue)")
            }
        } label: {
            Text("Category")
        }
        .accessibilityIdentifier("field_category")
    }
}

/// The unit of a food, as a menu. The first value is "No unit".
struct UnitPicker: View {
    @Binding var selection: MeasureUnit?

    var body: some View {
        Picker(selection: $selection) {
            Text(verbatim: Wording.unitName(nil))
                .tag(MeasureUnit?.none)
                .accessibilityIdentifier("unit_option_none")
            ForEach(MeasureUnit.allCases, id: \.self) { unit in
                Text(verbatim: Wording.unitName(unit))
                    .tag(MeasureUnit?.some(unit))
                    .accessibilityIdentifier("unit_option_\(unit.rawValue)")
            }
        } label: {
            Text("Unit")
        }
        .accessibilityIdentifier("field_unit")
    }
}

/// The storage kind of a storage area, as a menu.
struct StorageKindPicker: View {
    @Binding var selection: StorageKind

    var body: some View {
        Picker(selection: $selection) {
            ForEach(StorageKind.allCases, id: \.self) { kind in
                Text(verbatim: kind.label)
                    .tag(kind)
                    .accessibilityIdentifier("storage_kind_option_\(kind.rawValue)")
            }
        } label: {
            Text("Storage kind")
        }
        .accessibilityIdentifier("field_storage_kind")
    }
}

/// The storage area of a batch, as a menu: Fridge, Freezer, and then the other storage areas by name. The last item
/// of the menu opens the screen of the storage areas.
///
/// A selection that is not a storage area of the inventory shows "Select a storage area." as the problem: another
/// action deleted the storage area while the form was open.
///
/// ```swift
/// StorageAreaPicker(selection: $areaId, areas: content.inventory.storageAreas) { navigator.present(.storageAreas) }
/// ```
struct StorageAreaPicker: View {
    @Binding private var selection: String
    private let areas: [StorageArea]
    private let onManage: (() -> Void)?

    /// - Parameter onManage: Opens the screen of the storage areas, or nil for no such item.
    init(selection: Binding<String>, areas: [StorageArea], onManage: (() -> Void)? = nil) {
        _selection = selection
        self.areas = StorageAreaPicker.ordered(areas)
        self.onManage = onManage
    }

    var body: some View {
        let selected = areas.first { $0.id == selection }
        VStack(alignment: .leading, spacing: Space.s1) {
            LabeledContent {
                Menu {
                    ForEach(areas, id: \.id) { area in
                        Toggle(isOn: isSelected(area.id)) {
                            Label(area.displayName, systemImage: area.kind.icon.symbol)
                        }
                        .accessibilityIdentifier("area_option_\(area.id)")
                    }
                    if let onManage {
                        Divider()
                        Button("Manage storage areas", systemImage: AppIcon.edit.symbol, action: onManage)
                            .accessibilityIdentifier("manage_areas")
                    }
                } label: {
                    HStack(spacing: Space.s1) {
                        Text(verbatim: selected?.displayName ?? String(localized: "Select"))
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                    .formRowTarget()
                }
                .formRowTargetInRow()
                .accessibilityLabel(Text("Storage area"))
                .accessibilityValue(Text(verbatim: selected?.displayName ?? ""))
                .accessibilityIdentifier("field_area")
            } label: {
                Text("Storage area")
            }
            if selected == nil {
                FieldProblem(String(localized: "Select a storage area."), identifier: "error_area")
            }
        }
    }

    private func isSelected(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selection == id },
            set: { on in
                if on {
                    selection = id
                }
            }
        )
    }

    /// The order of the storage areas on each screen: Fridge, Freezer, and then the others by name.
    static func ordered(_ areas: [StorageArea]) -> [StorageArea] {
        func rank(_ area: StorageArea) -> Int {
            switch area.id {
            case StorageArea.fridge.id: 0
            case StorageArea.freezer.id: 1
            default: 2
            }
        }
        return areas.sorted { first, second in
            if rank(first) != rank(second) {
                return rank(first) < rank(second)
            }
            let names = Names.order(first.name, second.name)
            if names != .orderedSame {
                return names == .orderedAscending
            }
            return first.id.utf8.lexicographicallyPrecedes(second.id.utf8)
        }
    }
}

/// The note of a food: a text field that grows to five lines.
struct NoteField: View {
    @Binding var text: String

    var body: some View {
        TextField("Note", text: $text, prompt: Text("For example: opened on Sunday"), axis: .vertical)
            .lineLimit(1...5)
            .accessibilityIdentifier("field_note")
    }
}

extension View {
    /// Makes the label of a menu in a row of a form a target of 44 points or more: the label gets the space above
    /// and below it that a row has around its content. Use it on the label, and `formRowTargetInRow()` on the menu.
    func formRowTarget() -> some View {
        padding(.vertical, Space.s3)
            .frame(minHeight: Metrics.minTarget)
            .contentShape(.rect)
    }

    /// Takes the space of `formRowTarget()` out of the layout again, so that the row is as high as a row with a
    /// picker of the system. The target stays: it uses the space that the row has around its content.
    func formRowTargetInRow() -> some View {
        padding(.vertical, -Space.s3)
    }
}
