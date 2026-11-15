import CVKEFridgeFeatures
import SwiftUI

/// The form that adds food, in a sheet. It takes the place of `ui/AddFoodScreen.kt` of the Android app: the same
/// fields in the same order, with the controls of iOS.
///
/// 1. After a scan: where the values come from, and the barcode (`ScanNote`). In an empty form that the person fills
///    in by hand: the "Scan a barcode" card (`ScanCard`).
/// 2. The name, with the suggestions below it (`AddFoodNames.swift`). A name of a product in the inventory makes the
///    form short: it adds a batch to that product, and the category and the unit are those of the product.
/// 3. The category, the quantity, the unit, and the storage area.
/// 4. The storage tips (`StorageTipsSection`).
/// 5. The expiry date. An estimated date shows as an estimate, with the food of the table that gives it.
/// 6. The note, and the photo (`AddFoodPhoto.swift`).
///
/// The rules of the form are in `AddFoodForm` of `CVKEFridgeFeatures`. This file has only the state of the screen.
///
/// Differences from the Android app, on purpose:
/// - A product that the person selects from the suggestions always gets the values of "Add again". The Android app
///   gives them only to a recent food and to a food that the person has none of.
/// - A form with no name opens with the keyboard in the name field. The Android app does that only after a scan.
/// - "Scan a barcode" asks before it drops a changed form.
/// - A selected suggestion closes the keyboard, so that the person sees the values that the form now has.
struct AddFoodSheet: View {
    let productId: String?
    let openAreaId: String?
    let scan: Scanned?
    let again: Bool

    var body: some View {
        InventoryFormGate(title: "Add food", route: route) { content in
            AddFoodFormView(route: route, productId: productId, openAreaId: openAreaId, scan: scan, content: content) {
                AddFoodForm.start(
                    productId: productId,
                    openAreaId: openAreaId,
                    scan: scan,
                    again: again,
                    inventory: content.inventory,
                    changes: content.changes,
                    foods: content.foods,
                    lastAreaId: content.lastAreaId,
                    locale: .current
                )
            }
        }
    }

    private var route: SheetRoute {
        .addFood(productId: productId, openAreaId: openAreaId, scan: scan, again: again)
    }
}

/// The form of one food, and the form with no change of the person. The two are equal until the person changes a
/// field.
private struct AddFoodEntry: Equatable {
    var form: AddFoodForm
    var unchanged: AddFoodForm

    init(_ form: AddFoodForm) {
        self.form = form
        unchanged = form
    }

    /// True when the person changed a field. A "Save" that showed the problems is not a change.
    var isChanged: Bool {
        var plain = form
        plain.checked = unchanged.checked
        return plain != unchanged
    }
}

/// A field of the form that can have the keyboard.
private enum AddFoodField: Hashable {
    case name
    case quantity
    case note
}

/// A row of the form that the form scrolls to.
private enum AddFoodRow: Hashable {
    case top
    case name
    case quantity
    case area
    case saveFailed
}

private struct AddFoodFormView: View {
    let route: SheetRoute
    let productId: String?
    let openAreaId: String?
    let scan: Scanned?
    let content: FridgeContent
    /// Makes the form that the sheet opens with. The view calls it until it is on the screen. After that, a change
    /// of the inventory does not change the form below the fingers of the person.
    let start: () -> AddFoodForm

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The showing of this form. A save that ends after the form closed does not close a newer sheet.
    @Environment(\.sheetPresentation) private var presentation

    @State private var entry: AddFoodEntry?
    /// The token of this form for its writes and its photo.
    @State private var token = UUID().uuidString
    /// True when the last save was "Save and add another" or "Save and scan next".
    @State private var another = false
    /// The result of the last search for suggestions.
    @State private var found: [NameSuggestion] = []
    @State private var asksBeforeScan = false
    @FocusState private var focus: AddFoodField?

    /// What the rows of the form show. The body calculates it one time for each update.
    private struct Values {
        let entry: AddFoodEntry
        let existing: Product?
        let existingInStock: Bool
        let estimate: FoodEstimate?
        let area: StorageArea?
        let advice: StorageAdvice?
        let write: FormWrite?
        let photo: FormPhoto?
        let hasPhotoField: Bool
        let names: NameList

        var form: AddFoodForm { entry.form }
        /// True while the form cannot save: a write runs, or the app makes the photo.
        var isBusy: Bool { write == .saving || photo == .making }
    }

    var body: some View {
        let values = values()
        ScrollViewReader { proxy in
            FormSheet(
                "Add food",
                identifier: "add_food_screen",
                hasChanges: values.entry.isChanged || values.photo != nil,
                onClose: close
            ) {
                top(values)
                nameSection(values)
                detailsSection(values)
                if let advice = values.advice {
                    StorageTipsSection(advice: advice)
                }
                expirySection(values)
                noteSection(values)
                if values.hasPhotoField {
                    AddFoodPhotoSection(token: token)
                }
                if case .failed(let reason) = values.write {
                    FormSaveFailedNote(reason: reason)
                        .id(AddFoodRow.saveFailed)
                }
            } actions: {
                Button(scan == nil ? "Save and add another" : "Save and scan next") { save(another: true, proxy: proxy) }
                    .buttonStyle(.floatingSecondary)
                    .disabled(values.isBusy)
                    .accessibilityHint(busyHint(values))
                    .accessibilityIdentifier(scan == nil ? "save_another" : "save_scan_next")
                Button("Save") { save(another: false, proxy: proxy) }
                    .buttonStyle(.floatingPrimary)
                    .disabled(values.isBusy)
                    .accessibilityHint(busyHint(values))
                    .accessibilityIdentifier("save")
            }
            .motion(Motion.list, value: values.names)
            // The scanner takes the place of the form, so a changed form asks first, as its close button does.
            .confirmationDialog("Discard your changes?", isPresented: $asksBeforeScan, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive, action: openScanner)
                Button("Keep editing", role: .cancel) {}
            }
            .task(id: query(values)) { await search(values) }
            .onChange(of: values.write) { _, write in
                switch write {
                case .saved:
                    saved(proxy: proxy)
                case .failed:
                    // The message is the last row of the form. It can be below the screen.
                    scroll(proxy, to: .saveFailed, anchor: .bottom)
                case .saving, nil:
                    break
                }
            }
            .onChange(of: values.names.scrollsToName) { _, scrolls in
                // The suggestions are below the name. With the keyboard open, they need the room above the name.
                if scrolls {
                    scroll(proxy, to: .name, anchor: .top)
                }
            }
        }
        .onAppear {
            if entry == nil {
                let first = AddFoodEntry(start())
                entry = first
                // With no name, the person types the name first: an empty form, and a scan with no product.
                if first.form.name.isEmpty {
                    focus = .name
                }
            }
        }
        .onDisappear {
            // A sheet above the form does not close the form. Only a form that is gone drops its photo.
            if !navigator.sheets.contains(route) {
                model.discardFormPhoto(token: token)
            }
        }
    }

    // MARK: - The values of one update

    private func values() -> Values {
        let entry = entry ?? AddFoodEntry(start())
        let form = entry.form
        let inventory = content.inventory
        let existing = form.product(inventory.products)
        return Values(
            entry: entry,
            existing: existing,
            existingInStock: existing.map { AddAgain.inStock(inventory: inventory, productId: $0.id) } ?? false,
            estimate: form.estimated(
                products: inventory.products,
                areas: inventory.storageAreas,
                foods: content.foods,
                today: content.today
            ),
            area: inventory.storageAreas.first { $0.id == form.storageAreaId },
            advice: form.storageAdvice(products: inventory.products, foods: content.foods),
            write: model.formWrite(token),
            photo: model.formPhotos[token],
            // A food in the inventory that has a photo keeps it. The form then has no photo field.
            hasPhotoField: existing.map { model.photos[$0.id] == nil } ?? true,
            names: names(form, existing: existing)
        )
    }

    /// The list below the name field. It shows only while the name field has the keyboard.
    private func names(_ form: AddFoodForm, existing: Product?) -> NameList {
        guard focus == .name else {
            return .none
        }
        if form.name.allSatisfy(\.isWhitespace) {
            // A form after a scan has its own name, so it does not show the recent foods.
            guard scan == nil else {
                return .none
            }
            let recent = model.shownRecent.map { product in
                NameSuggestion(
                    suggestion: .ofProduct(product),
                    inStock: AddAgain.inStock(inventory: content.inventory, productId: product.id)
                )
            }
            return recent.isEmpty ? .none : .recent(recent)
        }
        return searches(form, existing: existing) && !found.isEmpty ? .found(found) : .none
    }

    /// False for a name that is complete: the name of a product, or the name or an alias of the food of the form.
    /// Such a name has no suggestions (`AddFoodForm.suggestions`), and the form does not start the search.
    private func searches(_ form: AddFoodForm, existing: Product?) -> Bool {
        if existing != nil || form.name.allSatisfy(\.isWhitespace) {
            return false
        }
        if let food = form.foodId.flatMap({ content.foods.food(id: $0) }), AddFoodForm.isNamed(food, form.name) {
            return false
        }
        return true
    }

    // MARK: - The suggestions

    /// The values that the suggestions come from. A change of one of them starts the search again.
    private struct Query: Equatable {
        let name: String
        let foodId: String?
        let searches: Bool
        /// The inventory and the table of foods, as two numbers that change when they change.
        let changes: Int
        let foods: Int
    }

    private func query(_ values: Values) -> Query {
        Query(
            name: values.form.name,
            foodId: values.form.foodId,
            searches: searches(values.form, existing: values.existing),
            changes: content.changes.count,
            foods: content.foods.foods.count
        )
    }

    /// Finds the suggestions for the name, after the person stopped typing for a short time. The search compares the
    /// text with each food of the table, also with one wrong letter, so it runs off the main actor. A new letter
    /// cancels the wait of the letter before it.
    private func search(_ values: Values) async {
        guard searches(values.form, existing: values.existing) else {
            found = []
            return
        }
        try? await Task.sleep(for: NameSuggestions.typingPause)
        if Task.isCancelled {
            return
        }
        let result = await NameSuggestions.find(for: values.form, inventory: content.inventory, foods: content.foods)
        if !Task.isCancelled {
            found = result
        }
    }

    private func select(_ suggestion: Suggestion) {
        let areas = content.inventory.storageAreas
        update { form in
            form = form.withSuggestion(suggestion, foods: content.foods, areas: areas)
            // A product gets the storage area of its newest batch and its usual quantity.
            if case .ofProduct(let product) = suggestion {
                form = form.again(
                    AddAgain.values(inventory: content.inventory, productId: product.id, changes: content.changes),
                    locale: .current
                )
            }
        }
        found = []
        Haptic.selection.play()
        // The keyboard closes, and the person sees the values that the form has now.
        focus = nil
    }

    // MARK: - The rows

    @ViewBuilder
    private func top(_ values: Values) -> some View {
        if let scan, scan.source != .inInventory {
            Section {
                ScanNote(scan: scan)
                    .id(AddFoodRow.top)
            }
        } else if scan == nil, productId == nil {
            // A new food can come from a barcode. The card is first in the form, so the scanner is one tap away.
            Section {
                ScanCard(action: scanTapped)
                    .id(AddFoodRow.top)
            }
        }
    }

    private func nameSection(_ values: Values) -> some View {
        let form = values.form
        let problem = form.checked ? form.nameError()?.foodMessage : nil
        let existingNote = values.existing == nil ? nil : values.existingInStock
            ? String(localized: "This food is in your inventory. The form adds a batch to it.")
            : String(localized: "You had this food before. The form adds a new batch to it.")
        return Section {
            VStack(alignment: .leading, spacing: Space.s1 + 2) {
                TextField("Name", text: nameBinding)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .focused($focus, equals: .name)
                    .onSubmit { focus = .quantity }
                    .accessibilityHint(Text(verbatim: problem ?? existingNote ?? ""))
                    .accessibilityIdentifier("field_name")
                if let problem {
                    FieldProblem(problem, identifier: "error_name")
                } else if let existingNote {
                    Text(verbatim: existingNote)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .accessibilityIdentifier("name_existing")
                }
                if case .recent = values.names {
                    Text("Recent")
                        .font(Typography.label.weight(.semibold))
                        .foregroundStyle(Palette.primary)
                        .padding(.top, Space.s2)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("suggestions_recent")
                }
            }
            .id(AddFoodRow.name)
            ForEach(values.names.rows) { row in
                NameSuggestionRow(
                    row: row,
                    onSelect: { select(row.suggestion) },
                    onRemove: values.names.isRecent ? { model.hideRecent(productId: $0) } : nil
                )
            }
        }
    }

    private func detailsSection(_ values: Values) -> some View {
        let form = values.form
        let areas = content.inventory.storageAreas
        return Section {
            if values.existing == nil {
                CategoryPicker(selection: edit(\.category) { form, category in
                    form.category = category
                    form.categoryChosen = true
                })
            }
            QuantityField(
                text: edit(\.quantity),
                problem: form.checked ? form.quantityError(locale: .current) : nil,
                // The unit of a product in the inventory is the unit of all its batches.
                unit: values.existing?.unit.map { Wording.unitName($0) }
            )
            .focused($focus, equals: .quantity)
            .id(AddFoodRow.quantity)
            if values.existing == nil {
                UnitPicker(selection: edit(\.unit))
            }
            StorageAreaPicker(
                selection: edit(\.storageAreaId) { form, id in form = form.withArea(id) },
                areas: areas
            ) {
                navigator.present(.storageAreas)
            }
            .id(AddFoodRow.area)
        }
    }

    private func expirySection(_ values: Values) -> some View {
        let suggested = values.estimate?.expiry
        return Section {
            ExpiryDateField(
                input: edit(\.expiry),
                expiry: ExpiryChoice.expiry(values.form.expiry, suggested: suggested),
                suggested: suggested,
                // The hint names the food of the table that gives the estimate.
                estimateHint: Wording.estimateHint(food: values.estimate?.food, kind: values.area?.kind),
                today: content.today
            )
        }
    }

    private func noteSection(_ values: Values) -> some View {
        Section {
            NoteField(text: edit(\.note) { form, text in form = form.withNote(text) })
                .focused($focus, equals: .note)
        } header: {
            Text("Note")
        } footer: {
            // The add form does not remove a note: an empty field keeps the note of the food.
            if values.existing?.note != nil, Notes.clean(values.form.note) == nil {
                Text("This food has a note. An empty field keeps it.")
                    .accessibilityIdentifier("note_kept")
            }
        }
    }

    private func busyHint(_ values: Values) -> Text {
        values.photo == .making ? Text("Not available while the app adds the photo.") : Text(verbatim: "")
    }

    // MARK: - The changes of the form

    private func update(_ change: (inout AddFoodForm) -> Void) {
        var next = entry ?? AddFoodEntry(start())
        change(&next.form)
        entry = next
    }

    /// A binding to one value of the form. `change` sets a value that has a rule of the form.
    private func edit<Value>(
        _ keyPath: WritableKeyPath<AddFoodForm, Value>,
        change: ((inout AddFoodForm, Value) -> Void)? = nil
    ) -> Binding<Value> {
        Binding(
            get: { (entry?.form ?? start())[keyPath: keyPath] },
            set: { value in
                update { form in
                    if let change {
                        change(&form, value)
                    } else {
                        form[keyPath: keyPath] = value
                    }
                }
            }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { entry?.form.name ?? start().name },
            set: { text in
                // The text field also sets its text when the text did not change. That is not a new name.
                guard text != (entry?.form.name ?? start().name) else {
                    return
                }
                update { form in
                    form = form.withName(text, foods: content.foods, areas: content.inventory.storageAreas)
                }
            }
        )
    }

    // MARK: - Save and close

    private func save(another: Bool, proxy: ScrollViewProxy) {
        // The buttons are off while the form saves or makes the photo. This check is for a tap in the same moment.
        guard model.formWrite(token) != .saving, model.formPhotos[token] != .making else {
            return
        }
        let form = entry?.form ?? start()
        let inventory = content.inventory
        guard let action = form.action(
            products: inventory.products,
            areas: inventory.storageAreas,
            foods: content.foods,
            today: content.today,
            locale: .current
        ) else {
            update { $0.checked = true }
            Haptic.error.play()
            showFirstProblem(of: form, proxy: proxy)
            return
        }
        self.another = another
        let existing = form.product(inventory.products)
        let takesPhoto = existing.map { model.photos[$0.id] == nil } ?? true
        model.perform(.addFood(action), formToken: token, photo: takesPhoto ? model.formPhoto(token) : nil)
    }

    /// Brings the first field with a problem on the screen, and gives it the keyboard.
    private func showFirstProblem(of form: AddFoodForm, proxy: ScrollViewProxy) {
        let field: AddFoodField?
        let row: AddFoodRow
        if form.nameError() != nil {
            (field, row) = (.name, .name)
        } else if form.quantityError(locale: .current) != nil {
            (field, row) = (.quantity, .quantity)
        } else {
            (field, row) = (nil, .area)
        }
        scroll(proxy, to: row, anchor: .center)
        if let field {
            // The list makes the row first, when the row was not on the screen.
            Task {
                try? await Task.sleep(for: .milliseconds(80))
                focus = field
            }
        }
    }

    /// The changes of the form are in the change log.
    private func saved(proxy: ScrollViewProxy) {
        model.formWriteRead(token)
        // The saved food got the photo. A photo that it did not get, because it has one, goes.
        model.discardFormPhoto(token: token)
        if scan != nil {
            navigator.finishAddFood(route, presentation: presentation, scanNext: another)
        } else if another {
            entry = AddFoodEntry((entry?.form ?? start()).next())
            found = []
            // A form for a product has no card above the name.
            scroll(proxy, to: productId == nil ? .top : .name, anchor: .top)
            focus = .name
        } else {
            navigator.finishAddFood(route, presentation: presentation)
        }
    }

    private func close() {
        model.discardFormPhoto(token: token)
        navigator.dismiss(route)
    }

    private func scanTapped() {
        let entry = entry ?? AddFoodEntry(start())
        if entry.isChanged || model.formPhotos[token] != nil {
            asksBeforeScan = true
        } else {
            openScanner()
        }
    }

    /// Shows the scanner in the place of this form. A form that the scanner opened closes, and the scanner below it
    /// shows again.
    private func openScanner() {
        model.discardFormPhoto(token: token)
        let below = navigator.sheets.prefix { $0 != route }
        if case .scan = below.last {
            navigator.dismiss(route)
        } else {
            navigator.replaceSheet(with: .scan(openAreaId: openAreaId))
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to row: AddFoodRow, anchor: UnitPoint) {
        withMotion(Motion.list, reduceMotion: reduceMotion) {
            proxy.scrollTo(row, anchor: anchor)
        }
    }
}
