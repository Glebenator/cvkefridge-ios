import CVKEFridgeFeatures
import Observation
import SwiftUI

/// The tabs of the app. Home and My Fridge have the names of FridgeFriend. The add button at the tab bar is not a tab:
/// it opens the add form (see `RootView`).
enum AppTab: String, Hashable, CaseIterable, Sendable {
    case home
    case myFridge
    case history
    case settings

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .myFridge: "My Fridge"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var icon: AppIcon {
        switch self {
        case .home: .home
        case .myFridge: .fridge
        case .history: .history
        case .settings: .settings
        }
    }

    /// The identifier of the tab for the UI tests. The Android app has the same tags.
    var identifier: String {
        switch self {
        case .home: "tab_home"
        case .myFridge: "tab_my_fridge"
        case .history: "tab_history"
        case .settings: "tab_settings"
        }
    }
}

/// A screen that opens in the navigation stack of a tab, with the back button of the system.
enum Route: Hashable, Sendable {
    /// One product with its batches.
    case food(productId: String)
    /// The list of the storage areas.
    case storageAreas
}

/// A screen that opens as a sheet above the tabs, or above another sheet.
enum SheetRoute: Hashable, Identifiable, Sendable {
    /// The form that adds food.
    ///
    /// - `productId`: The product that gets a batch, or nil for a form with no name.
    /// - `openAreaId`: The storage area that My Fridge showed when the person opened the form, or nil.
    /// - `scan`: The values of a scan, or nil for a form that the person fills in by hand. A form with a scan has the
    ///   button "Save and scan next".
    /// - `again`: True for "Add again" and "Add a batch": the form starts with the storage area of the newest batch
    ///   of the product and its usual quantity.
    case addFood(productId: String? = nil, openAreaId: String? = nil, scan: Scanned? = nil, again: Bool = false)
    /// The barcode scanner, with the explanation of the camera permission and the product lookup. `openAreaId` is the
    /// storage area that My Fridge showed, or nil. The add form gets it.
    case scan(openAreaId: String? = nil)
    /// The form that edits a product.
    case editProduct(productId: String)
    /// The form that edits a batch.
    case editBatch(batchId: String)
    /// The list of the storage areas, from "Manage storage areas" of a form.
    case storageAreas

    var id: SheetRoute { self }

    /// How the sheet shows.
    enum Style: Sendable {
        /// A sheet for a form. On an iPad it has the width of a form.
        case form
        /// A screen that covers all of the window: the camera of the scanner.
        case cover
    }

    var style: Style {
        switch self {
        case .scan: .cover
        case .addFood, .editProduct, .editBatch, .storageAreas: .form
        }
    }
}

/// Where the person is in the app: the selected tab, the screens in the stack of each tab, the sheets, and the filter
/// of My Fridge. It is one observable object, and each screen calls it to go to another screen:
///
/// ```swift
/// @Environment(Navigator.self) private var navigator
///
/// navigator.open(.food(productId: row.productId))
/// navigator.present(.editBatch(batchId: batch.id))
/// navigator.addFood()
/// navigator.showMyFridge(FoodFilter(freshness: [.expired]))
/// navigator.dismiss()
/// ```
///
/// No screen makes its own `NavigationStack` for these routes or shows them with its own `sheet`. A screen can show a
/// small sheet or a dialog of its own, for example a date picker.
@Observable
@MainActor
final class Navigator {
    /// The selected tab. Set it with `select(_:)`.
    private(set) var tab: AppTab

    /// The screens above the first screen of each tab, the newest last. `RootView` binds them to the stacks.
    var paths: [AppTab: [Route]] = [:]

    /// The sheets, the newest last. A sheet shows above the sheet before it.
    private(set) var sheets: [SheetRoute] = []

    /// The filters and the search text of My Fridge. They are here, because Home and a reminder open My Fridge with a
    /// filter. The sort order is not a filter: My Fridge keeps it.
    var myFridgeFilter = FoodFilter(areaId: StorageArea.fridge.id)

    /// A number that changes each time My Fridge starts again: a tap on its tab while it is selected, and a tap on a
    /// reminder. My Fridge then closes its search field and scrolls to the top.
    private(set) var myFridgeRestarts = 0

    init(tab: AppTab = .home) {
        self.tab = tab
    }

    // MARK: Tabs

    /// Selects a tab. A tap on the tab that is selected goes back to its first screen. For My Fridge, it also starts
    /// My Fridge again: the Fridge, with no category, no freshness, and no search text. The sort order stays.
    func select(_ newTab: AppTab) {
        guard newTab == tab else {
            tab = newTab
            return
        }
        if !(paths[newTab] ?? []).isEmpty {
            paths[newTab] = []
        } else if newTab == .myFridge {
            restartMyFridge(with: FoodFilter(areaId: StorageArea.fridge.id))
        }
    }

    /// Shows My Fridge with the filter: all sheets close, and My Fridge shows its first screen. "View all" of Home
    /// gives an empty filter, and a count of Home gives its freshness.
    func showMyFridge(_ filter: FoodFilter = FoodFilter()) {
        sheets = []
        paths[.myFridge] = []
        tab = .myFridge
        restartMyFridge(with: filter)
    }

    /// A tap on a reminder: My Fridge with the food that is expiring or expired, in all storage areas.
    func showAttention(_ freshness: Set<Freshness> = [.expiring, .expired]) {
        showMyFridge(FoodFilter(freshness: freshness))
    }

    private func restartMyFridge(with filter: FoodFilter) {
        myFridgeFilter = filter
        myFridgeRestarts += 1
    }

    /// The storage area that My Fridge shows, when My Fridge is the selected tab. A new form starts in it.
    var openAreaId: String? {
        tab == .myFridge ? myFridgeFilter.areaId : nil
    }

    // MARK: Screens in the stack of a tab

    /// Opens a screen in the stack of the selected tab. The sheets close first. Two fast taps do not open the same
    /// screen two times.
    func open(_ route: Route) {
        sheets = []
        if paths[tab]?.last != route {
            paths[tab, default: []].append(route)
        }
    }

    /// Goes back to the first screen of the selected tab.
    func popToRoot() {
        paths[tab] = []
    }

    /// Goes back one screen in the stack of the selected tab.
    func pop() {
        if !(paths[tab] ?? []).isEmpty {
            paths[tab]?.removeLast()
        }
    }

    // MARK: Sheets

    /// Shows a sheet above the screen, or above the sheet that is open. Two fast taps do not open the same sheet two
    /// times.
    func present(_ sheet: SheetRoute) {
        if sheets.last != sheet {
            sheets.append(sheet)
        }
    }

    /// Opens the form that adds food, in the storage area that My Fridge shows.
    func addFood() {
        present(.addFood(openAreaId: openAreaId))
    }

    /// Opens the scanner. The add form after the scan starts in the storage area that My Fridge shows.
    func scan() {
        present(.scan(openAreaId: openAreaId))
    }

    /// Puts a sheet in the place of the newest sheet: the scanner takes the place of the empty add form. With no
    /// sheet open, it shows the sheet.
    func replaceSheet(with sheet: SheetRoute) {
        if sheets.isEmpty {
            sheets = [sheet]
        } else {
            sheets[sheets.count - 1] = sheet
        }
    }

    /// Closes the newest sheet.
    func dismiss() {
        if !sheets.isEmpty {
            sheets.removeLast()
        }
    }

    /// Closes the sheet and each sheet above it. A sheet that is not open changes nothing.
    func dismiss(_ sheet: SheetRoute) {
        if let index = sheets.lastIndex(of: sheet) {
            sheets.removeSubrange(index...)
        }
    }

    /// Closes all sheets.
    func dismissAll() {
        sheets = []
    }

    /// Closes the add form after its save. "Save" also closes the scanner below the form. "Save and scan next"
    /// (`scanNext`) closes only the form, and the scanner shows again.
    func finishAddFood(_ sheet: SheetRoute, scanNext: Bool = false) {
        dismiss(sheet)
        if !scanNext, case .scan = sheets.last {
            sheets.removeLast()
        }
    }

    /// The sheet at a level, or nil. `SheetLayer` binds it.
    func sheet(at level: Int) -> SheetRoute? {
        sheets.indices.contains(level) ? sheets[level] : nil
    }

    /// Closes the sheet at the level and each sheet above it, when the system closed the sheet.
    func closeSheets(from level: Int) {
        if sheets.count > level {
            sheets.removeSubrange(level...)
        }
    }
}
