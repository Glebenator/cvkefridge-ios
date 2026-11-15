import CVKEFridgeFeatures
import SwiftUI

/// Records food as used or as thrown away, with a quantity that the person types. It takes the place of
/// `ui/TakeDialog.kt` of the Android app. My Fridge and the screen of a food use it.
///
/// ```swift
/// @State private var take: TakeRequest?
///
/// content.takeQuantity($take)
/// take = TakeRequest(productId: row.productId, batchIds: row.batchIds, outcome: .used)
/// ```
///
/// - A screen keeps `@State var take: TakeRequest?` and adds `.takeQuantity($take)`. To start, it sets the request.
/// - With only one item left (`TakeRequest.withoutDialog`), the modifier records it with no question.
/// - With more, it shows a small sheet with the quantity field. The field starts with the quantity of the oldest
///   batch. A quantity that is more than the oldest batch has comes from the next batches also.
/// - The modifier calls `model.perform(.take(…))` and sets the binding to nil. The message with "Undo" comes from
///   the model.
/// - A request for batches that are not in the inventory does nothing, and the sheet closes when another action
///   removes its batches.
extension View {
    func takeQuantity(_ request: Binding<TakeRequest?>) -> some View {
        modifier(TakeQuantityModifier(request: request))
    }
}

private struct TakeQuantityModifier: ViewModifier {
    @Binding var request: TakeRequest?
    @Environment(FridgeModel.self) private var model

    /// The request that the sheet shows, or nil when no sheet is open.
    @State private var asked: Asked?

    /// A request with an identifier, so that a second request for the same food opens the sheet again.
    private struct Asked: Identifiable {
        let id = UUID()
        let request: TakeRequest
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: request, initial: true) { _, new in
                start(new)
            }
            .sheet(item: $asked) {
                // The person closed the sheet, or the sheet recorded the quantity.
                request = nil
            } content: { asked in
                TakeQuantitySheet(request: asked.request) { self.asked = nil }
            }
    }

    private func start(_ new: TakeRequest?) {
        guard let new else {
            asked = nil
            return
        }
        guard let inventory = model.content?.inventory, TakeSource.of(inventory: inventory, request: new) != nil else {
            request = nil
            return
        }
        if let action = new.withoutDialog(inventory) {
            // With one item left, there is no quantity to choose.
            request = nil
            model.perform(.take(action))
        } else if asked?.request != new {
            asked = Asked(request: new)
        }
    }
}

extension TakeSource {
    /// The quantity in the `text`, a problem of the text, or `tooMuch`. The text is in the number format of the
    /// `locale`, as each quantity field of the app: German "1.000" is 1000.
    ///
    /// `check(_:)` reads the text with no locale, as the Android app does. That reads "1.000" as 1 for each locale.
    func check(_ text: String, locale: Locale) -> TakeCheck {
        switch QuantityText.parse(text, locale: locale) {
        case .invalid(let problem):
            return .problem(problem)
        case .value(let thousandths):
            return thousandths > available ? .tooMuch : .quantity(thousandths)
        }
    }
}

/// The sheet with the question "How much was used?" or "How much was thrown away?": the quantity field with the
/// unit, what the person has, and the button that records the quantity.
private struct TakeQuantitySheet: View {
    let request: TakeRequest
    let onClose: () -> Void

    @Environment(FridgeModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var text: String?
    /// True after the person selected the button one time. The field then shows its problem.
    @State private var checked = false
    @State private var problems = 0
    /// True after the sheet recorded the quantity. The sheet is on the screen while it closes, and a second tap on
    /// its button in that time does not record the quantity a second time.
    @State private var recorded = false

    private var used: Bool { request.outcome == .used }

    var body: some View {
        let source = model.content.flatMap { TakeSource.of(inventory: $0.inventory, request: request) }
        NavigationStack {
            Group {
                if let source {
                    form(source)
                } else {
                    // Another action removed the batches while the sheet was open.
                    Color.clear.onAppear(perform: onClose)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                        .accessibilityIdentifier("take_close")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: FormSheetKeyboard.hide)
                }
            }
        }
        // The sheet has the height of its content with the usual text sizes. Large text needs all of the screen.
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .tint(Palette.primary)
        .accessibilityIdentifier("take_dialog")
    }

    private func form(_ source: TakeSource) -> some View {
        let shown = text ?? QuantityText.format(source.firstQuantity, locale: .current)
        let check = source.check(shown, locale: .current)
        let available = Wording.quantity(source.available, unit: source.unit)
        return Form {
            Section {
                QuantityField(
                    text: Binding(get: { shown }, set: { text = $0 }),
                    problem: nil,
                    problemText: checked ? problemText(check, available: available) : nil,
                    unit: source.unit.map { Wording.unitName($0) }
                )
                .listRowBackground(Palette.surfaceContainer)
            } header: {
                (used ? Text("How much was used?") : Text("How much was thrown away?"))
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.onSurface)
                    .textCase(nil)
                    .padding(.bottom, Space.s2)
                    .accessibilityAddTraits(.isHeader)
            } footer: {
                // The field is above these words, so that it is on the screen also with the largest text.
                Text("\(source.name): you have \(available). The quantity comes from the oldest batch first.")
                    .font(Typography.secondary)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .accessibilityIdentifier("take_available")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .contentWidth()
        .bottomActionBar {
            Button {
                confirm(check)
            } label: {
                Label(used ? "Used" : "Thrown away", icon: used ? .check : .delete)
            }
            .buttonStyle(.floatingPrimary)
            .accessibilityHint(used ? Text("Records the quantity as used.") : Text("Records the quantity as thrown away."))
            .accessibilityIdentifier("take_confirm")
        }
        .haptic(.error, trigger: problems)
    }

    /// The words below the field for a quantity that the sheet cannot record, or nil.
    private func problemText(_ check: TakeCheck, available: String) -> String? {
        switch check {
        case .quantity:
            nil
        case .problem(let problem):
            problem.message
        case .tooMuch:
            String(localized: "You have only \(available).", comment: "The value is a quantity with its unit.")
        }
    }

    private func confirm(_ check: TakeCheck) {
        guard !recorded else {
            return
        }
        guard case .quantity(let thousandths) = check else {
            checked = true
            problems += 1
            return
        }
        recorded = true
        model.perform(
            .take(.init(productId: request.productId, batchIds: request.batchIds, quantity: thousandths, outcome: request.outcome))
        )
        onClose()
    }
}
