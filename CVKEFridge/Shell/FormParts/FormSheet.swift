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
/// - The close button closes the sheet with `onClose`. When `hasChanges` is true, it asks first, and a swipe down
///   asks the same question. So a changed form does not drop its changes with no question.
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
                        .discardQuestion(isPresented: $asksToDiscard, onDiscard: onClose)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: FormSheetKeyboard.hide)
                }
            }
        }
        .accessibilityIdentifier(identifier)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            FormSheetKeyboard.measureToolbar()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            FormSheetKeyboard.keyboardClosed()
        }
        .interactiveDismissDisabled(hasChanges)
        // A swipe down on a changed form asks the same question as the close button. A form with no change closes.
        .background {
            DismissAttemptReader(onAttempt: close)
                .accessibilityHidden(true)
        }
    }

    private func close() {
        if hasChanges {
            asksToDiscard = true
        } else {
            onClose()
        }
    }
}

extension View {
    /// The question before a changed form drops its changes: "Discard changes" and "Keep editing". Put it on the
    /// control that asks, so that on an iPad the question points to it.
    ///
    /// On an iPhone, the system does not show a button with the role `cancel` in such a question. So "Keep editing"
    /// has no role: it shows on each device, and VoiceOver reads it. A tap out of the question and the escape gesture
    /// of VoiceOver also close the question with no change.
    func discardQuestion(isPresented: Binding<Bool>, onDiscard: @escaping () -> Void) -> some View {
        confirmationDialog("Discard your changes?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive, action: onDiscard)
            Button("Keep editing") {}
        }
    }
}

/// Tells when the person tries to close the sheet of the view with a swipe down, while the sheet does not let the
/// swipe close it (`interactiveDismissDisabled`). SwiftUI has no such event, so the reader puts a delegate before the
/// delegate of SwiftUI on the presentation of the sheet. That delegate gives each call to the delegate of SwiftUI.
private struct DismissAttemptReader: UIViewControllerRepresentable {
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> ReaderController {
        ReaderController(onAttempt: onAttempt)
    }

    func updateUIViewController(_ controller: ReaderController, context: Context) {
        controller.onAttempt = onAttempt
        controller.install()
    }

    final class ReaderController: UIViewController {
        var onAttempt: () -> Void
        private let relay = DismissAttemptRelay()

        init(onAttempt: @escaping () -> Void) {
            self.onAttempt = onAttempt
            super.init(nibName: nil, bundle: nil)
            relay.onAttempt = { [weak self] in self?.onAttempt() }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not available")
        }

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            install()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        /// Puts the relay on the presentation of the sheet. SwiftUI can set its delegate again, so each update does
        /// this again.
        func install() {
            var root: UIViewController = self
            while let parent = root.parent {
                root = parent
            }
            guard let presentation = root.presentationController else {
                return
            }
            if presentation.delegate !== relay {
                relay.next = presentation.delegate
                presentation.delegate = relay
            }
        }
    }
}

/// The delegate of a presentation that tells the attempts to close it, and gives all calls to the delegate before it.
private final class DismissAttemptRelay: NSObject, UIAdaptivePresentationControllerDelegate {
    var onAttempt: (() -> Void)?
    /// The delegate of SwiftUI. UIKit calls `responds(to:)` and `forwardingTarget(for:)`, which are not isolated, only
    /// on the main thread.
    nonisolated(unsafe) weak var next: (any UIAdaptivePresentationControllerDelegate)?

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        next?.presentationControllerDidAttemptToDismiss?(presentationController)
        onAttempt?()
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (next?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if let next, next.responds(to: selector) {
            return next
        }
        return super.forwardingTarget(for: selector)
    }
}

/// The keyboard of a form.
@MainActor
enum FormSheetKeyboard {
    /// Closes the keyboard.
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// The field that has the keyboard, while `measureToolbar()` finds it.
    private static weak var firstResponder: UIResponder?

    /// Makes the system measure the bar with "Done" above the keyboard again.
    ///
    /// When a field gets the keyboard, the safe area of the sheet first has a bar above the keyboard that is 34
    /// points too low, so the buttons of the form are partly below "Done". The system corrects the safe area at the
    /// first change of the keyboard, for example the first key. A load of the input views of the field after the
    /// keyboard shows gives that correction at once. It does not change the field or its text.
    ///
    /// A sheet that closes does not get the load: its field would keep the keyboard open above the screen below. Each
    /// field gets one load while the keyboard is open, because the load shows the keyboard again.
    static func measureToolbar() {
        firstResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.cvkeFindFirstResponder(_:)), to: nil, from: nil, for: nil)
        defer { firstResponder = nil }
        guard let field = firstResponder as? UIView, field !== measuredField, field.window != nil, !isClosing(field) else {
            return
        }
        measuredField = field
        field.reloadInputViews()
    }

    /// The keyboard closed. The next field that gets the keyboard gets a load again.
    static func keyboardClosed() {
        measuredField = nil
    }

    /// The field that got the last load.
    private static weak var measuredField: UIView?

    /// True when the presentation that shows the view closes, or a presentation below it closes.
    private static func isClosing(_ view: UIView) -> Bool {
        var responder: UIResponder? = view
        while let next = responder, !(next is UIViewController) {
            responder = next.next
        }
        var controller = responder as? UIViewController
        while let current = controller {
            if current.isBeingDismissed || current.isMovingFromParent {
                return true
            }
            controller = current.parent ?? current.presentingViewController
        }
        return false
    }

    fileprivate static func found(_ responder: UIResponder) {
        firstResponder = responder
    }
}

extension UIResponder {
    /// The action that `FormSheetKeyboard` sends to the first responder to find it.
    @objc fileprivate func cvkeFindFirstResponder(_ sender: Any?) {
        FormSheetKeyboard.found(self)
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
