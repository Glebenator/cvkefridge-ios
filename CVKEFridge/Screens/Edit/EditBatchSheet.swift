import CVKEFridgeFeatures
import SwiftUI

/// The form that edits a batch, in a sheet. PLACEHOLDER: this file is a short form that saves, with the shared form
/// parts. The Edit agent replaces the body. The signature `EditBatchSheet(batchId:)` stays.
///
/// Contract:
/// - The sheet is the root view of `SheetRoute.editBatch`. Use `InventoryFormGate` and `FormSheet`.
/// - The form is `BatchForm.of(batch, locale: .current)`. `form.suggested(…)` gives the estimated date, and
///   `form.action(batch:product:areas:foods:locale:)` gives the action, or nil. Give `locale: .current` also to
///   `form.quantityError`.
/// - Fields: `QuantityField`, `StorageAreaPicker` (with `navigator.present(.storageAreas)`), `CalendarDateField` for
///   the date added (not after today), and `ExpiryDateField`.
/// - Save with `model.perform(.editBatch(action), formToken: token)` and read `model.formWrite(token)`. An edit that
///   changes nothing writes nothing. The message "Batch of … saved" with "Undo" comes from the model.
struct EditBatchSheet: View {
    let batchId: String

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @State private var form: BatchForm?
    @State private var token = UUID().uuidString

    private var route: SheetRoute { .editBatch(batchId: batchId) }

    var body: some View {
        InventoryFormGate(title: "Edit batch", route: route) { content in
            if let batch = content.inventory.batches.first(where: { $0.id == batchId }),
               let product = content.inventory.products.first(where: { $0.id == batch.productId }) {
                fields(batch, product, content)
            } else {
                MissingFormSubject(title: "Edit batch", message: RejectionReason.unknownBatch.message, route: route)
            }
        }
    }

    private func fields(_ batch: Batch, _ product: Product, _ content: FridgeContent) -> some View {
        let start = BatchForm.of(batch, locale: .current)
        let form = form ?? start
        let areas = content.inventory.storageAreas
        let suggested = form.suggested(batch: batch, product: product, areas: areas, foods: content.foods)
        let write = model.formWrite(token)
        return FormSheet("Edit batch", identifier: "edit_batch_screen", hasChanges: form != start, onClose: { navigator.dismiss(route) }) {
            Section {
                QuantityField(
                    text: edit(\.quantity, start),
                    problem: form.checked ? form.quantityError(locale: .current) : nil,
                    unit: product.unit.map { Wording.unitName($0) }
                )
                StorageAreaPicker(selection: edit(\.storageAreaId, start), areas: areas) {
                    navigator.present(.storageAreas)
                }
                CalendarDateField("Date added", date: edit(\.dateAdded, start), latest: content.today)
            } header: {
                Text(verbatim: product.name)
            }
            Section {
                ExpiryDateField(
                    input: edit(\.expiry, start),
                    expiry: ExpiryChoice.expiry(form.expiry, suggested: suggested),
                    suggested: suggested,
                    estimateHint: nil,
                    today: content.today
                )
            }
            if case .failed(let reason) = write {
                FormSaveFailedNote(reason: reason)
            }
        } actions: {
            Button("Save") {
                var current = form
                guard let action = current.action(batch: batch, product: product, areas: areas, foods: content.foods, locale: .current) else {
                    current.checked = true
                    self.form = current
                    return
                }
                model.perform(.editBatch(action), formToken: token)
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

    private func edit<Value>(_ keyPath: WritableKeyPath<BatchForm, Value>, _ start: BatchForm) -> Binding<Value> {
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
