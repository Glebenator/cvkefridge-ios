import CVKEFridgeFeatures
import SwiftUI

/// The small sheet for a typed barcode: one field with the number keyboard, "Look up", and "Cancel". It accepts the
/// digits with spaces or hyphens, as packages print them. "Look up" shows the problem of a text that is not a
/// barcode: a wrong number of digits, or a wrong check digit. Such a text is not looked up.
///
/// Eight digits can be an EAN-8 and also a UPC-E. `onLookUp` gets each barcode that the text can be
/// (`Barcodes.typedCandidates`), and the lookup tries the inventory and the cache with each of them.
struct BarcodeEntrySheet: View {
    /// The person selected "Look up" with a valid barcode. The value has one barcode or two.
    let onLookUp: (_ candidates: [String]) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    /// True after "Look up" with a text that is not a barcode. A change of the text makes it false.
    @State private var checked = false
    /// The number of refused texts, for the haptic signal.
    @State private var refusals = 0
    @FocusState private var focused: Bool

    private var problem: String? {
        guard checked, case .invalid(let problem) = Barcodes.parseTyped(text) else {
            return nil
        }
        return Wording.text(problem)
    }

    var body: some View {
        let problem = problem
        let help = String(localized: "The 8, 12, 13, or 14 digits below the lines of the barcode.")
        NavigationStack {
            Form {
                Section {
                    TextField("Barcode", text: $text)
                        .keyboardType(.numberPad)
                        .textContentType(nil)
                        .autocorrectionDisabled()
                        .font(.title3.monospacedDigit())
                        .focused($focused)
                        .submitLabel(.search)
                        .onSubmit(confirm)
                        .accessibilityHint(Text(verbatim: problem ?? help))
                        .accessibilityIdentifier("field_barcode")
                        .listRowBackground(Palette.surfaceContainer)
                } footer: {
                    if let problem {
                        FieldProblem(problem, identifier: "error_barcode")
                    } else {
                        Text(verbatim: help)
                            .accessibilityIdentifier("barcode_help")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.surface.ignoresSafeArea())
            .navigationTitle("Type the barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                        .accessibilityIdentifier("barcode_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Look up", action: confirm)
                        .disabled(text.allSatisfy(\.isWhitespace))
                        .accessibilityIdentifier("barcode_look_up")
                }
            }
        }
        .noticeHost()
        .presentationDetents([.medium, .large])
        .haptic(.error, trigger: refusals)
        .onChange(of: text) { _, _ in checked = false }
        .onAppear { focused = true }
        .accessibilityIdentifier("barcode_sheet")
    }

    private func confirm() {
        let candidates = Barcodes.typedCandidates(text)
        if candidates.isEmpty {
            checked = true
            refusals += 1
            if case .invalid(let problem) = Barcodes.parseTyped(text) {
                AccessibilityNotification.Announcement(Wording.text(problem)).post()
            }
        } else {
            onLookUp(candidates)
        }
    }
}
