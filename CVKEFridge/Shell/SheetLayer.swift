import SwiftUI

/// Shows the sheet of the navigator at one level above a view. The root of the app has level 0, and each sheet has
/// the layer of the next level, so a sheet can open above a sheet: the add form above the scanner.
///
/// A `SheetRoute` with the style `form` shows as a sheet, and with the style `cover` as a screen that covers the
/// window.
struct SheetLayer: ViewModifier {
    let level: Int

    @Environment(Navigator.self) private var navigator

    func body(content: Content) -> some View {
        content
            .sheet(item: route(.form)) { route in
                SheetRoot(route: route, level: level + 1)
                    .presentationSizing(.form)
            }
            .fullScreenCover(item: route(.cover)) { route in
                SheetRoot(route: route, level: level + 1)
            }
    }

    /// The sheet of this level when it has the `style`. When the system closes the sheet, for example after a swipe
    /// down, the navigator closes it and each sheet above it.
    private func route(_ style: SheetRoute.Style) -> Binding<SheetRoute?> {
        Binding(
            get: {
                guard let route = navigator.sheet(at: level), route.style == style else {
                    return nil
                }
                return route
            },
            set: { route in
                // A change of the route at this level also arrives here, with the old style. Only a sheet that the
                // system closed has no route of this style now.
                if route == nil, navigator.sheet(at: level)?.style == style {
                    navigator.closeSheets(from: level)
                }
            }
        )
    }
}

/// The root view of a sheet of the navigator: the screen of the route, the place of the messages above it, and the
/// layer for a sheet above it.
struct SheetRoot: View {
    let route: SheetRoute
    /// The number of this sheet: 1 for the first sheet above the tabs.
    let level: Int

    @Environment(Navigator.self) private var navigator

    var body: some View {
        screen
            .noticeHost()
            // While the sheet closes, the message shows below it.
            .environment(\.noticeHostEnabled, navigator.sheets.count >= level)
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
