import CVKEFridgeFeatures
import SwiftUI

/// The form that adds food, in a sheet. PLACEHOLDER: this file is a short form that saves, with the shared form
/// parts. It has no suggestions, no scan card, no recent foods, no storage tips, and no photo field. The Add agent
/// replaces the body. The signature `AddFoodSheet(productId:openAreaId:scan:again:)` stays.
///
/// Contract:
/// - The sheet is the root view of `SheetRoute.addFood`. Use `FormSheet` for the frame.
/// - The start value of the form is `AddFoodForm.start(productId:openAreaId:scan:again:inventory:changes:foods:
///   lastAreaId:locale:)`, with `content.changes`, `content.lastAreaId`, and `Locale.current`. It has the correction
///   for a scan of a barcode that the inventory has.
/// - The quantity text is in the number format of the locale: give `locale: .current` to `form.quantityError`,
///   `form.action`, and `form.again`. A selected suggestion of a product gets
///   `AddAgain.values(inventory:productId:changes:)`.
/// - The estimate and its food: `form.estimated(…)` (a `FoodEstimate`), for the text below the expiry date
///   (`Wording.estimateHint`).
/// - Save: `form.action(…)` gives the action, or nil when a field has a problem (then set `form.checked`). Call
///   `model.perform(.addFood(action), formToken: token, photo: …)` with one token for the form, and read
///   `model.formWrite(token)`: `.saving` (the buttons are off), `.saved` (call `model.formWriteRead(token)`, then
///   close or start the next food with `form.next()`), `.failed(reason)` (show `FormSaveFailedNote`). The model does
///   nothing for a second call while the form saves, so two fast taps add one batch.
/// - Close: `navigator.dismiss(route)`. After a save: `navigator.finishAddFood(route)`, which also closes the scanner
///   below the form. "Save and scan next": `navigator.finishAddFood(route, scanNext: true)`, which shows the scanner
///   again.
/// - "Scan a barcode" in an empty form: `navigator.replaceSheet(with: .scan(openAreaId:))`.
/// - "Manage storage areas": `navigator.present(.storageAreas)`.
/// - Recent foods: `model.shownRecent`, and `model.hideRecent(productId:)`.
/// - The photo of the form: `model.formPhotos[token]` (`.making`, `.ready`), `model.makeFormPhoto(token:picture:)`,
///   `model.discardFormPhoto(token:)` (also when the form closes with no save), and `model.formPhoto(token)` for
///   `perform`. "Save" is off, with a reason, while the photo is `.making`.
/// - The message "… added" with "Undo" comes from the model, also above this sheet.
struct AddFoodSheet: View {
    let productId: String?
    let openAreaId: String?
    let scan: Scanned?
    let again: Bool

    var body: some View {
        InventoryFormGate(title: "Add food", route: route) { content in
            AddFoodFormView(route: route, scan: scan, content: content, start: AddFoodForm.start(
                productId: productId,
                openAreaId: openAreaId,
                scan: scan,
                again: again,
                inventory: content.inventory,
                changes: content.changes,
                foods: content.foods,
                lastAreaId: content.lastAreaId,
                locale: .current
            ))
        }
    }

    private var route: SheetRoute {
        .addFood(productId: productId, openAreaId: openAreaId, scan: scan, again: again)
    }
}

private struct AddFoodFormView: View {
    let route: SheetRoute
    let scan: Scanned?
    let content: FridgeContent
    let start: AddFoodForm

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @State private var form: AddFoodForm?
    /// The form with no change of the person: the start form, or the empty form after "Save and add another".
    @State private var unchanged: AddFoodForm?
    @State private var token = UUID().uuidString
    @State private var another = false

    var body: some View {
        let start = unchanged ?? start
        let form = form ?? start
        let products = content.inventory.products
        let areas = content.inventory.storageAreas
        let existing = form.product(products)
        let suggested = form.estimate(products: products, areas: areas, foods: content.foods, today: content.today)
        let write = model.formWrite(token)
        FormSheet("Add food", identifier: "add_food_screen", hasChanges: form != start, onClose: { navigator.dismiss(route) }) {
            Section {
                VStack(alignment: .leading, spacing: Space.s1) {
                    TextField("Name", text: edit(\.name) { form, text in form.withName(text, foods: content.foods, areas: areas) })
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("field_name")
                    if form.checked, let problem = form.nameError() {
                        FieldProblem(problem.foodMessage, identifier: "error_name")
                    }
                }
                if existing == nil {
                    CategoryPicker(selection: edit(\.category) { form, category in
                        var next = form
                        next.category = category
                        next.categoryChosen = true
                        return next
                    })
                }
            }
            Section {
                QuantityField(
                    text: edit(\.quantity),
                    problem: form.checked ? form.quantityError(locale: .current) : nil,
                    unit: existing?.unit.map { Wording.unitName($0) }
                )
                if existing == nil {
                    UnitPicker(selection: edit(\.unit))
                }
                StorageAreaPicker(selection: edit(\.storageAreaId) { form, id in form.withArea(id) }, areas: areas) {
                    navigator.present(.storageAreas)
                }
            }
            Section {
                ExpiryDateField(
                    input: edit(\.expiry),
                    expiry: ExpiryChoice.expiry(form.expiry, suggested: suggested),
                    suggested: suggested,
                    estimateHint: Wording.estimateHint(
                        food: form.food(products: products, foods: content.foods),
                        kind: areas.first { $0.id == form.storageAreaId }?.kind
                    ),
                    today: content.today
                )
            }
            Section("Note") {
                NoteField(text: edit(\.note) { form, text in form.withNote(text) })
            }
            if case .failed(let reason) = write {
                FormSaveFailedNote(reason: reason)
            }
        } actions: {
            Button(scan == nil ? "Save and add another" : "Save and scan next") { save(another: true) }
                .buttonStyle(.floatingSecondary)
                .disabled(write == .saving)
                .accessibilityIdentifier(scan == nil ? "save_another" : "save_scan_next")
            Button("Save") { save(another: false) }
                .buttonStyle(.floatingPrimary)
                .disabled(write == .saving)
                .accessibilityIdentifier("save")
        }
        .onChange(of: write) { _, write in
            guard write == .saved else {
                return
            }
            model.formWriteRead(token)
            if scan != nil {
                navigator.finishAddFood(route, scanNext: another)
            } else if another {
                unchanged = form.next()
                self.form = nil
            } else {
                navigator.finishAddFood(route)
            }
        }
    }

    /// A binding to one value of the form. `change` gives the form after a new value.
    private func edit<Value>(
        _ keyPath: WritableKeyPath<AddFoodForm, Value>,
        change: ((AddFoodForm, Value) -> AddFoodForm)? = nil
    ) -> Binding<Value> {
        Binding(
            get: { (form ?? unchanged ?? start)[keyPath: keyPath] },
            set: { value in
                var next = form ?? unchanged ?? start
                if let change {
                    next = change(next, value)
                } else {
                    next[keyPath: keyPath] = value
                }
                form = next
            }
        )
    }

    private func save(another: Bool) {
        var current = form ?? unchanged ?? start
        let areas = content.inventory.storageAreas
        guard let action = current.action(
            products: content.inventory.products,
            areas: areas,
            foods: content.foods,
            today: content.today,
            locale: .current
        ) else {
            current.checked = true
            form = current
            return
        }
        self.another = another
        model.perform(.addFood(action), formToken: token)
    }
}
