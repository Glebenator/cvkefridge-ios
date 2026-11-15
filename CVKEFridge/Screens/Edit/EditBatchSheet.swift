import CVKEFridgeFeatures
import SwiftUI

/// The form that edits a batch, in a sheet: its quantity, its storage area, its date added, and its expiry date. It
/// takes the place of `EditBatchScreen` in `ui/EditScreens.kt` of the Android app.
///
/// - An estimated date follows a change of the storage area or of the date added. A printed date stays.
/// - A date that the person chose because the food was still good ("Your date") stays a chosen date until the person
///   selects a different date in the calendar. In the Android app, "OK" in the calendar makes each date a printed
///   date.
/// - The date added is not after today: a batch cannot come into the inventory in the future.
///
/// A save that changes a value has the message "Batch of … saved" with "Undo", which the model makes. A save that
/// changes nothing writes nothing.
struct EditBatchSheet: View {
    let batchId: String

    private var route: SheetRoute { .editBatch(batchId: batchId) }

    var body: some View {
        InventoryFormGate(title: "Edit batch", route: route) { content in
            if let batch = content.inventory.batches.first(where: { $0.id == batchId }),
               let product = content.inventory.products.first(where: { $0.id == batch.productId }) {
                EditBatchFormView(route: route, batch: batch, product: product, content: content)
            } else {
                // Another action deleted the batch while the form was open.
                MissingFormSubject(title: "Edit batch", message: RejectionReason.unknownBatch.message, route: route)
            }
        }
    }
}

private struct EditBatchFormView: View {
    let route: SheetRoute
    let batch: Batch
    let product: Product
    let content: FridgeContent

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The form after the first change of the person, or nil for the values of the batch.
    @State private var form: BatchForm?
    @State private var token = UUID().uuidString
    @FocusState private var quantityFocused: Bool

    private enum Row: Hashable {
        case quantity
        case area
        case saveFailed
    }

    private var start: BatchForm { BatchForm.of(batch, locale: .current) }

    var body: some View {
        let start = start
        let form = form ?? start
        let areas = content.inventory.storageAreas
        let write = model.formWrite(token)
        ScrollViewReader { proxy in
            FormSheet(
                "Edit batch",
                identifier: "edit_batch_screen",
                hasChanges: isChanged(form, from: start),
                onClose: { navigator.dismiss(route) }
            ) {
                Section {
                    QuantityField(
                        text: edit(\.quantity),
                        problem: form.checked ? form.quantityError(locale: .current) : nil,
                        unit: product.unit.map { Wording.unitName($0) }
                    )
                    .focused($quantityFocused)
                    .id(Row.quantity)
                    StorageAreaPicker(selection: edit(\.storageAreaId), areas: areas) {
                        navigator.present(.storageAreas)
                    }
                    .id(Row.area)
                    CalendarDateField("Date added", date: edit(\.dateAdded), latest: max(content.today, batch.dateAdded))
                        .accessibilityIdentifier("field_date_added")
                } header: {
                    // The name of the food says which batch the form edits.
                    Text(verbatim: product.name)
                        .accessibilityIdentifier("batch_food_name")
                }
                expirySection(form, areas: areas)
                if case .failed(let reason) = write {
                    FormSaveFailedNote(reason: reason)
                        .id(Row.saveFailed)
                }
            } actions: {
                Button("Save") { save(proxy: proxy) }
                    .buttonStyle(.floatingPrimary)
                    .disabled(write == .saving)
                    .accessibilityIdentifier("save")
            }
            .onChange(of: write) { _, write in
                switch write {
                case .saved:
                    model.formWriteRead(token)
                    navigator.dismiss(route)
                case .failed:
                    scroll(proxy, to: .saveFailed, anchor: .bottom)
                case .saving, nil:
                    break
                }
            }
        }
    }

    private func expirySection(_ form: BatchForm, areas: [StorageArea]) -> some View {
        let area = areas.first { $0.id == form.storageAreaId }
        let suggested = form.suggested(batch: batch, product: product, areas: areas, foods: content.foods)
        let food = product.foodId.flatMap { content.foods.food(id: $0) }
        var tableEstimate: ExpiryDate?
        if let food, let area {
            tableEstimate = content.foods.estimate(foodId: food.id, kind: area.kind, dateAdded: form.dateAdded)
        }
        return Section {
            ExpiryDateField(
                input: edit(\.expiry),
                expiry: ExpiryChoice.expiry(form.expiry, suggested: suggested),
                suggested: suggested,
                // The hint is true only for a date that comes from the table of foods for these values.
                estimateHint: suggested != nil && suggested == tableEstimate
                    ? Wording.estimateHint(food: food, kind: area?.kind)
                    : nil,
                today: content.today
            )
        }
    }

    /// True when the person changed a field. A "Save" that showed the problems is not a change.
    private func isChanged(_ form: BatchForm, from start: BatchForm) -> Bool {
        var plain = form
        plain.checked = start.checked
        return plain != start
    }

    private func edit<Value>(_ keyPath: WritableKeyPath<BatchForm, Value>) -> Binding<Value> {
        Binding(
            get: { (form ?? start)[keyPath: keyPath] },
            set: { value in
                var next = form ?? start
                next[keyPath: keyPath] = value
                form = next
            }
        )
    }

    private func save(proxy: ScrollViewProxy) {
        var current = form ?? start
        guard let action = current.action(
            batch: batch,
            product: product,
            areas: content.inventory.storageAreas,
            foods: content.foods,
            locale: .current
        ) else {
            current.checked = true
            form = current
            Haptic.error.play()
            // The first field with a problem comes on the screen. The quantity gets the keyboard.
            if current.quantityError(locale: .current) != nil {
                scroll(proxy, to: .quantity, anchor: .center)
                quantityFocused = true
            } else {
                scroll(proxy, to: .area, anchor: .center)
            }
            return
        }
        model.perform(.editBatch(action), formToken: token)
    }

    private func scroll(_ proxy: ScrollViewProxy, to row: Row, anchor: UnitPoint) {
        withMotion(Motion.list, reduceMotion: reduceMotion) {
            proxy.scrollTo(row, anchor: anchor)
        }
    }
}
