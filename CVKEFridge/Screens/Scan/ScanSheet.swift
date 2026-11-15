import CVKEFridgeFeatures
import SwiftUI

/// The barcode scanner, as a screen that covers the window. PLACEHOLDER: this file has no camera. The person types
/// the barcode, and the product lookup runs. The Scan agent replaces the body. The signature
/// `ScanSheet(openAreaId:)` stays.
///
/// Contract:
/// - The screen is the root view of `SheetRoute.scan`, which shows as a full screen cover. It has its own close
///   button: `navigator.dismiss(.scan(openAreaId:))`. The shell stops the lookup when the scanner closes.
/// - The camera: `model.camera.access()` and `model.camera.requestAccess()` (`CameraAccess`). Explain the camera
///   before the request. "Type the barcode" and "Add by hand" are always there, so the scanner works with no camera.
/// - A read of the camera: `Barcodes.fromScan(format:raw:)` and `ScanDebouncer`, then `model.lookUp(barcode)`.
/// - A typed barcode: `Barcodes.typedCandidates(text)` gives each barcode that the text can be. Call
///   `model.lookUp(candidates[0], otherForms: Array(candidates.dropFirst()))`. `Barcodes.parseTyped` gives the
///   problem of a text that is not a barcode.
/// - `model.lookup` is the state: `.idle`, `.looking(barcode:)`, `.done(id:scanned:productId:)`, or
///   `.failed(barcode:failure:)`. For `.done`, open the form above the scanner with
///   `navigator.present(.addFood(productId: productId, openAreaId: openAreaId, scan: scanned))`, and then call
///   `model.lookupShown(id)`. For `.failed`, offer "Try again" (`model.lookUp` again), "Enter by hand"
///   (`.addFood` with `Scanned(barcode:source: .notLookedUp)`), and "Scan again" (`model.cancelLookup()`).
/// - "Add by hand": `navigator.present(.addFood(openAreaId: openAreaId))`.
/// - The messages of the app show above this screen: `SheetRoot` has the place for them.
struct ScanSheet: View {
    let openAreaId: String?

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @State private var text = ""

    private var route: SheetRoute { .scan(openAreaId: openAreaId) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Barcode", text: $text)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("field_barcode")
                    Button("Look up") {
                        let candidates = Barcodes.typedCandidates(text)
                        if let first = candidates.first {
                            model.lookUp(first, otherForms: Array(candidates.dropFirst()))
                        }
                    }
                    .disabled(Barcodes.typedCandidates(text).isEmpty)
                    .accessibilityIdentifier("look_up")
                } footer: {
                    Text("The 8, 12, 13, or 14 digits below the lines of the barcode.")
                }
                Section {
                    switch model.lookup {
                    case .idle:
                        EmptyView()
                    case .looking(let barcode):
                        Text("Looking up barcode \(barcode)…")
                    case .done:
                        EmptyView()
                    case .failed(let barcode, _):
                        Button("Try again") { model.lookUp(barcode) }
                        Button("Enter by hand") {
                            navigator.present(.addFood(openAreaId: openAreaId, scan: Scanned(barcode: barcode, source: .notLookedUp)))
                        }
                    }
                }
                Section {
                    Button("Add by hand", systemImage: AppIcon.addByHand.symbol) {
                        navigator.present(.addFood(openAreaId: openAreaId))
                    }
                    .accessibilityIdentifier("scan_add_by_hand")
                }
            }
            .navigationTitle("Scan a barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { navigator.dismiss(route) }
                        .accessibilityIdentifier("scan_close")
                }
            }
        }
        .accessibilityIdentifier("scan_screen")
        .onChange(of: model.lookup, initial: true) { _, lookup in
            if case .done(let id, let scanned, let productId) = lookup {
                navigator.present(.addFood(productId: productId, openAreaId: openAreaId, scan: scanned))
                model.lookupShown(id)
            }
        }
    }
}
