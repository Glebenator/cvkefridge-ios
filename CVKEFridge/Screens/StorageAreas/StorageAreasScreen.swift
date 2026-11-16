import CVKEFridgeFeatures
import SwiftUI

/// The list of the storage areas: Fridge and Freezer, which are fixed, and the storage areas that the person
/// created. Each one shows its storage kind and its number of foods. The person can create a storage area, and edit
/// or delete one that is not fixed. It takes the place of `ui/StorageAreasScreen.kt` of the Android app.
///
/// - The screen shows in two places: in the navigation stack of My Fridge (`Route.storageAreas`), and in a sheet
///   above a form (`SheetRoute.storageAreas`, with a "Done" button that the shell adds). So it sets its navigation
///   title, and it does not make a `NavigationStack` and does not close itself.
/// - The order and the numbers of foods are those of the tabs of My Fridge.
/// - A tap on a storage area that is not fixed opens its form. A swipe, the "More" button, and a touch and hold
///   have "Edit" and "Delete". VoiceOver has the two as actions of the row.
/// - The core does not delete a storage area with food in it. The screen says how many foods are there and what to
///   do, before the write. The message of a delete has "Undo", and it comes from the model.
struct StorageAreasScreen: View {
    @Environment(FridgeModel.self) private var model

    /// The form of the sheet. It stays while the sheet closes.
    @State private var form = StorageAreaForm.of(nil)
    @State private var showsForm = false
    /// The storage area that the person cannot delete now, because it has food.
    @State private var inUse: AreaSummary?

    var body: some View {
        List {
            switch model.state {
            case .ready(let content):
                rows(content)
            case .loading, .failed:
                InventoryGate { _ in EmptyView() }
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .contentWidth()
        .background(Palette.surface.ignoresSafeArea())
        .navigationTitle("Storage areas")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsForm) {
            StorageAreaFormSheet(form: $form) {
                showsForm = false
            }
        }
        .alert(
            Text("\(inUse?.displayName ?? "") has food in it", comment: "The value is the name of a storage area."),
            isPresented: Binding(get: { inUse != nil }, set: { shown in if !shown { inUse = nil } }),
            presenting: inUse
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { area in
            Text(verbatim: inUseMessage(area))
        }
        .accessibilityIdentifier("storage_areas_screen")
    }

    @ViewBuilder
    private func rows(_ content: FridgeContent) -> some View {
        let areas = Dictionary(content.inventory.storageAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let shown = content.overview.areas.compactMap { summary in areas[summary.id].map { (area: $0, summary: summary) } }
        Section {
            ForEach(shown, id: \.area.id) { entry in
                StorageAreaRow(area: entry.area, foodCount: entry.summary.foodCount) {
                    edit(entry.area)
                } onDelete: {
                    delete(entry.summary)
                }
                .listRowBackground(Palette.surfaceContainer)
            }
        } footer: {
            if !shown.contains(where: { !$0.area.fixed }) {
                Text("Fridge and Freezer are always here. Add a storage area for a pantry, or for a second fridge or freezer.")
                    .accessibilityIdentifier("no_created_areas")
            }
        }
        .motion(Motion.list, value: shown.map(\.area.id))
        Section {
            Button {
                edit(nil)
            } label: {
                Label("Add a storage area", icon: .add)
                    .frame(maxWidth: .infinity, minHeight: Metrics.minTarget, alignment: .leading)
                    .contentShape(.rect)
            }
            .foregroundStyle(Palette.primary)
            .listRowBackground(Palette.surfaceContainer)
            .accessibilityIdentifier("add_area")
        }
    }

    /// Opens the form for the `area`, or for a new storage area.
    private func edit(_ area: StorageArea?) {
        form = StorageAreaForm.of(area)
        showsForm = true
    }

    private func delete(_ summary: AreaSummary) {
        if summary.foodCount > 0 {
            // The core rejects this delete. The screen says why before the person tries.
            Haptic.error.play()
            inUse = summary
        } else {
            model.perform(.deleteStorageArea(id: summary.id))
        }
    }

    private func inUseMessage(_ area: AreaSummary) -> String {
        let name = area.displayName
        let count = area.foodCount
        return count == 1
            ? String(localized: "\(name) has \(count) item. Move it to a different storage area, or record it as used or thrown away. Then delete the storage area.")
            : String(localized: "\(name) has \(count) items. Move them to a different storage area, or record them as used or thrown away. Then delete the storage area.")
    }
}

/// One storage area: the icon of its storage kind, its name, its storage kind, and its number of foods. A fixed
/// storage area says so and has no actions. The others open the form with a tap, and they have "Edit" and "Delete".
private struct StorageAreaRow: View {
    let area: StorageArea
    let foodCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if area.fixed {
            label
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("area_card_\(area.id)")
        } else {
            HStack(spacing: 0) {
                Button(action: onEdit) {
                    label
                        .contentShape(.rect)
                }
                .buttonStyle(.card)
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("Opens the form of the storage area."))
                .accessibilityAction(named: Text("Edit"), onEdit)
                .accessibilityAction(named: Text("Delete"), onDelete)
                .accessibilityIdentifier("area_card_\(area.id)")
                Menu {
                    actions
                } label: {
                    Image(icon: .more)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget)
                        .contentShape(.rect)
                }
                .accessibilityLabel(Text("More actions for \(area.displayName)"))
                .accessibilityIdentifier("area_menu_\(area.id)")
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", icon: .delete)
                }
                .accessibilityIdentifier("swipe_delete_area")
                Button(action: onEdit) {
                    Label("Edit", icon: .edit)
                }
                .tint(Palette.secondary)
                .accessibilityIdentifier("swipe_edit_area")
            }
            .contextMenu { actions }
        }
    }

    /// The icon, the name, and "Pantry • 2 items" or "Fridge • 8 items • Fixed".
    private var label: some View {
        let parts = [area.kind.label, Wording.itemCount(foodCount)] + (area.fixed ? [String(localized: "Fixed")] : [])
        return HStack(spacing: Space.s3) {
            IconTile(area.kind.icon, tone: area.fixed ? .neutral : .standard, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: area.displayName)
                    .font(Typography.body)
                    .foregroundStyle(Palette.onSurface)
                Text(verbatim: parts.joined(separator: " \(Wording.separator) "))
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Space.s1)
    }

    @ViewBuilder private var actions: some View {
        Button(action: onEdit) {
            Label("Edit", icon: .edit)
        }
        .accessibilityIdentifier("menu_edit_area")
        Divider()
        Button(role: .destructive, action: onDelete) {
            Label("Delete", icon: .delete)
        }
        .accessibilityIdentifier("menu_delete_area")
    }
}

/// The sheet that creates or edits a storage area: its name and its storage kind. The storage kind gives the expiry
/// estimate of the food in it. A write that fails leaves the sheet open, with what failed.
private struct StorageAreaFormSheet: View {
    @Binding var form: StorageAreaForm
    let onClose: () -> Void

    @Environment(FridgeModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var nameFocused: Bool
    /// The token of the save of this form. The sheet keeps it, so that it is the same for all of the time that the
    /// sheet is open: the result of the save has this token.
    @State private var token = UUID().uuidString
    /// The form as it was when the sheet opened, or nil before the first change.
    @State private var start: StorageAreaForm?
    @State private var problems = 0
    /// True after the save, while the sheet closes.
    @State private var saved = false

    var body: some View {
        let areas = model.content?.inventory.storageAreas ?? []
        let write = model.formWrite(token)
        // After the save, the new storage area has the name of the form. That is not a problem of the name.
        let nameError = form.checked && !saved ? form.nameError(areas: areas)?.areaMessage : nil
        FormSheet(
            form.id == nil ? "Add a storage area" : "Edit storage area",
            identifier: "area_dialog",
            hasChanges: start.map { changed(from: $0) } ?? false,
            onClose: onClose
        ) {
            Section {
                VStack(alignment: .leading, spacing: Space.s1) {
                    TextField("Name", text: $form.name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit { save(areas) }
                        .accessibilityHint(Text(verbatim: nameError ?? ""))
                        .accessibilityIdentifier("field_area_name")
                    if let nameError {
                        FieldProblem(nameError, identifier: "error_area_name")
                    }
                }
            }
            Section {
                StorageKindPicker(selection: $form.kind)
            } footer: {
                Text("The storage kind gives the estimated date of the food in this storage area.")
            }
            if case .failed(let reason) = write {
                FormSaveFailedNote(reason: reason)
            }
        } actions: {
            Button("Save") {
                save(areas)
            }
            .buttonStyle(.floatingPrimary)
            .disabled(write == .saving)
            .accessibilityIdentifier("area_save")
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .tint(Palette.primary)
        .haptic(.error, trigger: problems)
        .onAppear {
            start = form
            // A new storage area starts with the keyboard, because the name is the one thing to type.
            nameFocused = form.id == nil
        }
        .onChange(of: write) { _, write in
            if write == .saved {
                saved = true
                model.formWriteRead(token)
                onClose()
            }
        }
    }

    /// True when the person changed the name or the storage kind.
    private func changed(from start: StorageAreaForm) -> Bool {
        form.name != start.name || form.kind != start.kind
    }

    private func save(_ areas: [StorageArea]) {
        guard let action = form.action(areas: areas) else {
            form.checked = true
            problems += 1
            return
        }
        model.perform(.saveStorageArea(action), formToken: token)
    }
}
