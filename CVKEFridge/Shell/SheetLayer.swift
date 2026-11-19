import SwiftUI

/// Shows the sheet of the navigator at one level above a view. The root of the app has level 0, and each sheet has
/// the layer of the next level, so a sheet can open above a sheet: the add form above the scanner.
///
/// A `SheetRoute` with the style `form` shows as a sheet, and with the style `cover` as a screen that covers the
/// window.
///
/// The layer shows one presentation at a time. When the navigator puts a different presentation at this level, for
/// example the scanner in the place of the add form, the layer first closes the presentation that shows. It shows the
/// new presentation when the system tells that the first one closed (`onDismiss`). UIKit does not show a presentation
/// while a presentation of the same view closes, so a replacement in one update can fail with no error.
struct SheetLayer: ViewModifier {
    let level: Int

    @Environment(Navigator.self) private var navigator
    /// The presentation that the system shows, or nil.
    @State private var shown: SheetPresentation?
    /// True from the time that the layer closes a presentation until the system tells that it closed.
    @State private var closing = false

    func body(content: Content) -> some View {
        content
            .sheet(item: presentation(.form), onDismiss: closed) { presentation in
                SheetRoot(presentation: presentation, level: level + 1)
                    .presentationSizing(.form)
            }
            .fullScreenCover(item: presentation(.cover), onDismiss: closed) { presentation in
                SheetRoot(presentation: presentation, level: level + 1)
            }
            .onChange(of: navigator.presentation(at: level), initial: true) { _, wanted in
                follow(wanted)
            }
    }

    /// Makes the system show the presentation of the navigator.
    private func follow(_ wanted: SheetPresentation?) {
        if shown == wanted || closing {
            // While a presentation closes, `closed()` shows the newest wanted presentation.
            return
        }
        if shown == nil {
            shown = wanted
        } else {
            closing = true
            shown = nil
        }
    }

    /// The system closed the presentation of this level.
    private func closed() {
        closing = false
        shown = nil
        follow(navigator.presentation(at: level))
    }

    /// The presentation of this level when it has the `style`. When the system closes the presentation, for example
    /// after a swipe down, the navigator closes it and each sheet above it.
    private func presentation(_ style: SheetRoute.Style) -> Binding<SheetPresentation?> {
        Binding(
            get: {
                guard let shown, shown.route.style == style else {
                    return nil
                }
                return shown
            },
            set: { new in
                guard new == nil, let old = shown, old.route.style == style else {
                    return
                }
                // The system closes the presentation. `closed()` comes after the end of the animation.
                closing = true
                shown = nil
                navigator.closeSheets(from: old)
            }
        )
    }
}

/// The root view of a sheet of the navigator: the screen of the route, the place of the messages above it, and the
/// layer for a sheet above it.
struct SheetRoot: View {
    let presentation: SheetPresentation
    /// The number of this sheet: 1 for the first sheet above the tabs.
    let level: Int

    @Environment(Navigator.self) private var navigator

    private var route: SheetRoute {
        presentation.route
    }

    var body: some View {
        screen
            .noticeHost()
            // While the sheet closes, the message shows below it.
            .environment(\.noticeHostEnabled, navigator.presentation(at: level - 1) == presentation)
            .environment(\.sheetPresentation, presentation.id)
            .modifier(SheetLayer(level: level))
            .tint(Palette.primary)
    }

    @ViewBuilder private var screen: some View {
        switch route {
        case .addFood(let productId, let openAreaId, let scan, let again):
            AddFoodSheet(productId: productId, openAreaId: openAreaId, scan: scan, again: again)
        case .scan(let openAreaId):
            ScanSheet(openAreaId: openAreaId)
        case .editProduct(let productId):
            EditProductSheet(productId: productId)
        case .editBatch(let batchId):
            EditBatchSheet(batchId: batchId)
        case .storageAreas:
            StorageAreasSheet()
        }
    }
}

/// The list of the storage areas in a sheet, from "Manage storage areas" of a form. The screen is the same screen
/// that My Fridge opens in its stack.
private struct StorageAreasSheet: View {
    @Environment(Navigator.self) private var navigator

    var body: some View {
        NavigationStack {
            StorageAreasScreen()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { navigator.dismiss(.storageAreas) }
                            .accessibilityIdentifier("storage_areas_done")
                    }
                }
        }
    }
}
