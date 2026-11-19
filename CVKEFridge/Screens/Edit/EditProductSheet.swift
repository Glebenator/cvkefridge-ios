import CVKEFridgeFeatures
import SwiftUI

/// The form that edits a product, in a sheet: its name, its category, its unit, and its note. A product with a barcode
/// shows the barcode, and the person cannot change it. It takes the place of `EditProductScreen` in
/// `ui/EditScreens.kt` of the Android app.
///
/// The unit is the unit of all batches of the product. A change of the unit changes what the quantities mean, so the
/// form says what the save does (`ProductForm.unitChange`):
/// - g and kg, ml and l: the save converts the quantities, and the form shows an example.
/// - Each other pair: the numbers stay. The form says so, and "Save" asks the person first.
///
/// In the Android app, a change of the unit keeps the numbers with no question: 500 g becomes 500 kg.
///
/// A save that changes a value has the message "… saved" with "Undo", which the model makes. A save that changes
/// nothing writes nothing.
struct EditProductSheet: View {
    let productId: String

    private var route: SheetRoute { .editProduct(productId: productId) }

    var body: some View {
        InventoryFormGate(title: "Edit food", route: route) { content in
            if let product = content.inventory.products.first(where: { $0.id == productId }) {
                EditProductFormView(route: route, product: product, content: content)
            } else {
                // Another action deleted the product while the form was open.
                MissingFormSubject(title: "Edit food", message: RejectionReason.unknownProduct.message, route: route)
            }
        }
    }
}

private struct EditProductFormView: View {
    let route: SheetRoute
    let product: Product
    let content: FridgeContent

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The form after the first change of the person, or nil for the values of the product.
    @State private var form: ProductForm?
    @State private var token = UUID().uuidString
    @State private var asksAboutUnit = false
    @FocusState private var nameFocused: Bool

    private enum Row: Hashable {
        case name
        case saveFailed
    }

    var body: some View {
        let start = ProductForm.of(product)
        let form = form ?? start
        let write = model.formWrite(token)
        let unitChange = form.unitChange(product: product, inventory: content.inventory)
        let example = UnitChangeExample.of(product: product, newUnit: form.unit, inventory: content.inventory)
        ScrollViewReader { proxy in
            FormSheet(
                "Edit food",
                identifier: "edit_food_screen",
                hasChanges: isChanged(form, from: start),
                onClose: { navigator.dismiss(route) }
            ) {
                nameSection(form)
                unitSection(form, change: unitChange, example: example)
                Section("Note") {
                    NoteField(text: edit(\.note))
                }
                if let barcode = product.barcode {
                    barcodeSection(barcode)
                }
                if case .failed(let reason) = write {
                    FormSaveFailedNote(reason: reason)
                        .id(Row.saveFailed)
                }
            } actions: {
                Button("Save") { save(proxy: proxy) }
                    .buttonStyle(.floatingPrimary)
                    .disabled(write == .saving)
                    .accessibilityIdentifier("save")
                    .confirmationDialog(
                        Text(UnitChangeExample.question(newUnit: form.unit)),
                        isPresented: $asksAboutUnit,
                        titleVisibility: .visible
                    ) {
                        Button("Change the unit") { perform() }
                            .accessibilityIdentifier("unit_change_confirm")
                        // With the role `cancel`, an iPhone does not show the button. See `discardQuestion`.
                        Button("Keep editing") {}
                    } message: {
                        Text(verbatim: example?.keepsNumbers ?? UnitChangeExample.keepsNumbersPlain)
                    }
            }
            .motion(Motion.list, value: unitChange)
            .onChange(of: write) { _, write in
                switch write {
                case .saved:
                    model.formWriteRead(token)
                    navigator.dismiss(route)
                case .failed:
                    withMotion(Motion.list, reduceMotion: reduceMotion) {
                        proxy.scrollTo(Row.saveFailed, anchor: .bottom)
                    }
                case .saving, nil:
                    break
                }
            }
        }
    }

    // MARK: - The rows

    private func nameSection(_ form: ProductForm) -> some View {
        let problem = form.checked ? form.nameError(product: product, products: content.inventory.products)?.foodMessage : nil
        return Section {
            VStack(alignment: .leading, spacing: Space.s1 + 2) {
                TextField("Name", text: edit(\.name))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .accessibilityHint(Text(verbatim: problem ?? ""))
                    .accessibilityIdentifier("field_name")
                if let problem {
                    FieldProblem(problem, identifier: "error_name")
                }
            }
            .id(Row.name)
            CategoryPicker(selection: edit(\.category))
        }
    }

    private func unitSection(_ form: ProductForm, change: UnitChange, example: UnitChangeExample?) -> some View {
        Section {
            UnitPicker(selection: edit(\.unit))
            switch change {
            case .unchanged:
                EmptyView()
            case .converts:
                UnitChangeNote(
                    text: example?.converts ?? String(localized: "The app converts the quantities of the batches to the new unit."),
                    isWarning: false
                )
            case .keepsNumbers:
                UnitChangeNote(text: example?.keepsNumbers ?? UnitChangeExample.keepsNumbersPlain, isWarning: true)
            }
        } footer: {
            Text("The unit is the unit of all batches of this food.")
        }
    }

    private func barcodeSection(_ barcode: String) -> some View {
        Section {
            LabeledContent {
                Text(verbatim: barcode)
                    .monospacedDigit()
                    .textSelection(.enabled)
            } label: {
                Text("Barcode")
            }
            .accessibilityIdentifier("field_barcode")
        } footer: {
            Text("The app keeps the barcode with the food, so the next scan finds it. You can't change it here.")
        }
    }

    // MARK: - The changes of the form

    /// True when the person changed a field. A "Save" that showed the problems is not a change.
    private func isChanged(_ form: ProductForm, from start: ProductForm) -> Bool {
        var plain = form
        plain.checked = start.checked
        return plain != start
    }

    private func edit<Value>(_ keyPath: WritableKeyPath<ProductForm, Value>) -> Binding<Value> {
        Binding(
            get: { (form ?? ProductForm.of(product))[keyPath: keyPath] },
            set: { value in
                var next = form ?? ProductForm.of(product)
                next[keyPath: keyPath] = value
                form = next
            }
        )
    }

    // MARK: - Save

    private func save(proxy: ScrollViewProxy) {
        var current = form ?? ProductForm.of(product)
        guard current.action(product: product, products: content.inventory.products, foods: content.foods) != nil else {
            current.checked = true
            form = current
            Haptic.error.play()
            withMotion(Motion.list, reduceMotion: reduceMotion) {
                proxy.scrollTo(Row.name, anchor: .center)
            }
            nameFocused = true
            return
        }
        // The numbers of the batches stay with a unit that they were not typed for. The person decides.
        if current.unitChange(product: product, inventory: content.inventory) == .keepsNumbers {
            asksAboutUnit = true
        } else {
            perform()
        }
    }

    private func perform() {
        let current = form ?? ProductForm.of(product)
        if let action = current.action(product: product, products: content.inventory.products, foods: content.foods) {
            model.perform(.saveProduct(action), formToken: token)
        }
    }
}

/// What a change of the unit does to the quantities, below the unit: information for a conversion, and a warning
/// when the numbers stay. VoiceOver reads it when it comes.
private struct UnitChangeNote: View {
    let text: String
    let isWarning: Bool

    var body: some View {
        Label {
            Text(verbatim: text)
                .font(Typography.secondary)
                .foregroundStyle(Palette.onSurface)
        } icon: {
            Image(icon: isWarning ? .alert : .info, filled: true)
                .foregroundStyle(isWarning ? Palette.Status.expiring : Palette.primary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(isWarning ? "unit_keeps_numbers" : "unit_converts")
        .onAppear {
            AccessibilityNotification.Announcement(text).post()
        }
    }
}

/// The words for a change of the unit, with the quantity of one batch of the product as the example.
private struct UnitChangeExample {
    /// "The app converts the quantities of the batches. For example, 350 g becomes 0.35 kg."
    let converts: String
    /// "The numbers of the batches stay. For example, 350 g becomes 350 pcs. …"
    let keepsNumbers: String

    /// The text for a change that keeps the numbers, when the product has no batch for an example.
    static var keepsNumbersPlain: String {
        String(localized: "The numbers of the batches stay. The app can't convert between these two units.")
    }

    /// The question before the save: "Change the unit to pcs?"
    static func question(newUnit: MeasureUnit?) -> String {
        guard let newUnit else {
            return String(localized: "Remove the unit?")
        }
        return String(localized: "Change the unit to \(Wording.unitName(newUnit))?")
    }

    /// The example for the product and the unit of the form, or nil when the product has no active batch.
    static func of(product: Product, newUnit: MeasureUnit?, inventory: Inventory) -> UnitChangeExample? {
        guard let batch = inventory.activeBatches.first(where: { $0.productId == product.id }) else {
            return nil
        }
        let before = Wording.quantity(batch.quantity, unit: product.unit)
        let kept = Wording.quantity(batch.quantity, unit: newUnit)
        let converted = UnitConversion.convert(batch.quantity, from: product.unit, to: newUnit)
            .map { Wording.quantity($0, unit: newUnit) } ?? kept
        return UnitChangeExample(
            converts: String(localized: "The app converts the quantities of the batches. For example, \(before) becomes \(converted)."),
            keepsNumbers: String(localized: "The numbers of the batches stay. For example, \(before) becomes \(kept). The app can't convert between these two units.")
        )
    }
}
