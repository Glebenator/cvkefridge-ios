import CVKEFridgeFeatures
import SwiftUI
import UIKit

/// The frame of a form in a sheet: a navigation bar with the title and the close button, the fields in a grouped
/// `Form`, and the bar with the buttons at the bottom edge. It takes the place of `SubScreen`, `FormColumn`, and
/// `FormButtons` of `ui/FormParts.kt` of the Android app.
///
/// ```swift
/// FormSheet("Add food", identifier: "add_food_screen", hasChanges: form != start, onClose: { navigator.dismiss(route) }) {
///     Section { … fields … }
///     if let failed { FormSaveFailedNote(reason: failed) }
/// } actions: {
///     Button("Save and add another") { save(another: true) }.buttonStyle(.floatingSecondary)
///     Button("Save") { save(another: false) }.buttonStyle(.floatingPrimary)
/// }
/// ```
///
/// - The content is the content of a `Form`: sections with rows. The parts of `FormFields.swift` and
///   `ExpiryDateField.swift` are rows.
/// - Give the main action last. The buttons are Liquid Glass, and they stay above the keyboard.
/// - The close button closes the sheet with `onClose`. When `hasChanges` is true, it asks first, and the person
///   cannot close the sheet with a swipe down. So a changed form does not drop its changes with no question.
/// - The messages of the app show above the buttons.
/// - The keyboard has a "Done" button, because the decimal keyboard has no return key.
/// - On a wide screen the fields are not wider than `Metrics.contentMaxWidth`.
struct FormSheet<Content: View, Actions: View>: View {
    private let title: LocalizedStringKey
    private let identifier: String
    private let hasChanges: Bool
    private let onClose: () -> Void
    private let content: Content
    private let actions: Actions

    @State private var asksToDiscard = false

    /// - Parameters:
    ///   - identifier: The accessibility identifier of the form, for the UI tests.
    ///   - hasChanges: True when the person changed a field and did not save.
    ///   - onClose: Closes the sheet, for example `navigator.dismiss(route)`.
    init(
        _ title: LocalizedStringKey,
        identifier: String,
        hasChanges: Bool,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.identifier = identifier
        self.hasChanges = hasChanges
        self.onClose = onClose
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        NavigationStack {
            Form {
                content
                    .listRowBackground(Palette.surfaceContainer)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .contentWidth()
            .noticeHost()
            .bottomActionBar { actions }
            .background(Palette.surface.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: close)
                        .accessibilityIdentifier("form_close")
                        .confirmationDialog("Discard your changes?", isPresented: $asksToDiscard, titleVisibility: .visible) {
                            Button("Discard changes", role: .destructive, action: onClose)
                            Button("Keep editing", role: .cancel) {}
                        }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: FormSheetKeyboard.hide)
                }
            }
        }
        .accessibilityIdentifier(identifier)
        .interactiveDismissDisabled(hasChanges)
    }

    private func close() {
        if hasChanges {
            asksToDiscard = true
        } else {
            onClose()
        }
    }
}

/// The keyboard of a form.
@MainActor
enum FormSheetKeyboard {
    /// Closes the keyboard.
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// A write of a form failed: what failed and what to do, as a row of the form. VoiceOver reads it when it comes.
/// A failed write gives the error haptic.
///
/// ```swift
/// if case .failed(let reason) = model.formWrite(token) { FormSaveFailedNote(reason: reason) }
/// ```
struct FormSaveFailedNote: View {
    /// The reason of the core, or nil when the inventory file could not be written.
    let reason: RejectionReason?

    var body: some View {
        let text = Wording.saveFailed(reason)
        Label {
            Text(verbatim: text)
                .font(Typography.secondary)
        } icon: {
            Image(icon: .alert, filled: true)
        }
        .foregroundStyle(Palette.onErrorContainer)
        .listRowBackground(Palette.errorContainer)
        .accessibilityIdentifier("save_failed")
        .onAppear {
            Haptic.error.play()
            AccessibilityNotification.Announcement(text).post()
        }
    }
}

/// The problem of a field, below the field: an icon and the words, in the error colour. VoiceOver reads it with the
/// field when the field has `.accessibilityHint` with the same words.
struct FieldProblem: View {
    private let message: String
    private let identifier: String?

    /// - Parameter identifier: The accessibility identifier, for the UI tests, for example "error_name".
    init(_ message: String, identifier: String? = nil) {
        self.message = message
        self.identifier = identifier
    }

    var body: some View {
        Label {
            Text(verbatim: message)
        } icon: {
            Image(icon: .alert, filled: true)
        }
        .font(Typography.caption)
        .foregroundStyle(Palette.error)
        .accessibilityIdentifier(identifier ?? "field_problem")
    }
}

/// Shows the content when the inventory is loaded. Before that, it shows the loading line, or the failed load with
/// "Try again". Each screen and each form uses it, so that these two states are the same on each screen.
///
/// ```swift
/// InventoryGate { content in
///     List(content.overview.foods, id: \.key) { … }
/// }
/// ```
struct InventoryGate<Content: View>: View {
    @Environment(FridgeModel.self) private var model
    @ViewBuilder let content: (FridgeContent) -> Content

    var body: some View {
        switch model.state {
        case .ready(let ready):
            content(ready)
        case .loading:
            LoadingView(style: .plain)
                .accessibilityIdentifier("loading")
        case .failed:
            ErrorStateView(Wording.loadFailed) { model.load() }
                .accessibilityIdentifier("load_failed")
        }
    }
}

/// The frame of a form sheet while the inventory is not loaded: the title, the close button, and the loading line or
/// the failed load. When the inventory is loaded, it shows the form. Put it around the `FormSheet` of a form.
///
/// ```swift
/// InventoryFormGate(title: "Edit food", route: .editProduct(productId: productId)) { content in … FormSheet … }
/// ```
struct InventoryFormGate<Content: View>: View {
    let title: LocalizedStringKey
    let route: SheetRoute
    @ViewBuilder let content: (FridgeContent) -> Content

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator

    var body: some View {
        if let ready = model.content {
            content(ready)
        } else {
            NavigationStack {
                InventoryGate { _ in EmptyView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.surface.ignoresSafeArea())
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close) { navigator.dismiss(route) }
                        }
                    }
            }
        }
    }
}

/// The product or the batch of an edit form is not in the inventory: another action deleted it. The sheet says so, and
/// it has only the close button.
struct MissingFormSubject: View {
    let title: LocalizedStringKey
    let message: String
    let route: SheetRoute

    @Environment(Navigator.self) private var navigator

    var body: some View {
        NavigationStack {
            Text(verbatim: message)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.surface.ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { navigator.dismiss(route) }
                    }
                }
        }
    }
}
