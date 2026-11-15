import CVKEFridgeFeatures
import SwiftUI

/// The form that edits a product, in a sheet. PLACEHOLDER: this file is a short form that saves, with the shared form
/// parts. The Edit agent replaces the body. The signature `EditProductSheet(productId:)` stays.
///
/// Contract:
/// - The sheet is the root view of `SheetRoute.editProduct`. Use `InventoryFormGate` and `FormSheet`.
/// - The form is `ProductForm.of(product)`. Its problems are `form.nameError(product:products:)` and
///   `NameError.foodMessage`. `form.action(product:products:foods:)` gives the action, or nil.
/// - Save with `model.perform(.saveProduct(action), formToken: token)` and read `model.formWrite(token)`, as the add
///   form does. An edit that changes nothing writes nothing. An edit that changes a value shows the message
///   "… saved" with "Undo": the model makes it, also above this sheet while it closes.
/// - `form.unitChange(product:inventory:)` says what the save does to the quantities of the active batches:
///   `.converts` (g and kg, ml and l: the action converts them), or `.keepsNumbers` (each other pair: ask the person
///   before the save, and say that the numbers stay). This placeholder does not ask.
/// - A product that is not in the inventory: another action deleted it. Say so, and close.
struct EditProductSheet: View {
    let productId: String

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @State private var form: ProductForm?
    @State private var token = UUID().uuidString

    private var route: SheetRoute { .editProduct(productId: productId) }

    var body: some View {
        InventoryFormGate(title: "Edit food", route: route) { content in
            if let product = content.inventory.products.first(where: { $0.id == productId }) {
                fields(product, content)
            } else {
                MissingFormSubject(title: "Edit food", message: RejectionReason.unknownProduct.message, route: route)
            }
        }
    }

    private func fields(_ product: Product, _ content: FridgeContent) -> some View {
        let start = ProductForm.of(product)
        let form = form ?? start
        let write = model.formWrite(token)
        return FormSheet("Edit food", identifier: "edit_food_screen", hasChanges: form != start, onClose: { navigator.dismiss(route) }) {
            Section {
                VStack(alignment: .leading, spacing: Space.s1) {
                    TextField("Name", text: edit(\.name, start))
                        .accessibilityIdentifier("field_name")
                    if form.checked, let problem = form.nameError(product: product, products: content.inventory.products) {
                        FieldProblem(problem.foodMessage, identifier: "error_name")
                    }
                }
                CategoryPicker(selection: edit(\.category, start))
            }
            Section {
                UnitPicker(selection: edit(\.unit, start))
            } footer: {
                Text("The unit is the unit of all batches of this food.")
            }
            Section("Note") {
                NoteField(text: edit(\.note, start))
            }
            if case .failed(let reason) = write {
                FormSaveFailedNote(reason: reason)
            }
        } actions: {
            Button("Save") {
                var current = form
                guard let action = current.action(product: product, products: content.inventory.products, foods: content.foods) else {
                    current.checked = true
                    self.form = current
                    return
                }
                model.perform(.saveProduct(action), formToken: token)
            }
            .buttonStyle(.floatingPrimary)
            .disabled(write == .saving)
            .accessibilityIdentifier("save")
        }
        .onChange(of: write) { _, write in
            if write == .saved {
                model.formWriteRead(token)
                navigator.dismiss(route)
            }
        }
    }

    private func edit<Value>(_ keyPath: WritableKeyPath<ProductForm, Value>, _ start: ProductForm) -> Binding<Value> {
        Binding(
            get: { (form ?? start)[keyPath: keyPath] },
            set: { value in
                var next = form ?? start
                next[keyPath: keyPath] = value
                form = next
            }
        )
    }
}
