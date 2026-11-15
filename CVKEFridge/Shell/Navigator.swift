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

/// One showing of a sheet: the route, and a number that is different for each showing. Two showings of the same
/// route are two presentations. So a late call for a sheet that closed cannot close a newer sheet with the same route.
struct SheetPresentation: Hashable, Identifiable, Sendable {
    let id: Int
    let route: SheetRoute
}

extension EnvironmentValues {
    /// The presentation of the sheet that shows the view, or nil outside a sheet of the navigator.
    @Entry var sheetPresentation: SheetPresentation.ID?
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
    private(set) var presentations: [SheetPresentation] = []

    /// The routes of the sheets, the newest last.
    var sheets: [SheetRoute] {
        presentations.map(\.route)
    }

    /// The number of the newest presentation.
    @ObservationIgnored private var presentationCount = 0

    /// The filters and the search text of My Fridge. They are here, because Home and a reminder open My Fridge with a
    /// filter. The sort order is not a filter: My Fridge keeps it.
    var myFridgeFilter = FoodFilter(areaId: StorageArea.fridge.id)

    /// A number that changes each time My Fridge starts again: a tap on its tab while it is selected, and a tap on a
    /// reminder. My Fridge then closes its search field and scrolls to the top.
    private(set) var myFridgeRestarts = 0

    init(tab: AppTab = .home) {
        self.tab = tab
    }

    private func presentation(of route: SheetRoute) -> SheetPresentation {
        presentationCount += 1
        return SheetPresentation(id: presentationCount, route: route)
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
        presentations = []
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
        presentations = []
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
        if presentations.last?.route != sheet {
            presentations.append(presentation(of: sheet))
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
    ///
    /// The replacement is a new presentation. `SheetLayer` shows it after the system closed the sheet before it.
    func replaceSheet(with sheet: SheetRoute) {
        if presentations.isEmpty {
            presentations = [presentation(of: sheet)]
        } else {
            presentations[presentations.count - 1] = presentation(of: sheet)
        }
    }

    /// Closes the newest sheet.
    func dismiss() {
        if !presentations.isEmpty {
            presentations.removeLast()
        }
    }

    /// Closes the sheet and each sheet above it. A sheet that is not open changes nothing.
    func dismiss(_ sheet: SheetRoute) {
        if let index = presentations.lastIndex(where: { $0.route == sheet }) {
            presentations.removeSubrange(index...)
        }
    }

    /// Closes all sheets.
    func dismissAll() {
        presentations = []
    }

    /// Closes the add form after its save. "Save" also closes the scanner below the form. "Save and scan next"
    /// (`scanNext`) closes only the form, and the scanner shows again.
    ///
    /// The form must still be open. A save that ends after its form closed changes nothing: it does not close a
    /// scanner that the person opened after that. Only the scanner directly below the form closes.
    ///
    /// - Parameter presentation: The presentation of the form (`\.sheetPresentation`). With it, only that showing of
    ///   the form counts, and not a newer form with the same route. Without it, the newest sheet with the route
    ///   counts.
    func finishAddFood(_ sheet: SheetRoute, presentation: SheetPresentation.ID? = nil, scanNext: Bool = false) {
        let index = if let presentation {
            presentations.lastIndex { $0.id == presentation && $0.route == sheet }
        } else {
            presentations.lastIndex { $0.route == sheet }
        }
        guard let index else {
            return
        }
        var end = index
        if !scanNext, index > 0, case .scan = presentations[index - 1].route {
            end = index - 1
        }
        presentations.removeSubrange(end...)
    }

    /// The sheet at a level, or nil.
    func sheet(at level: Int) -> SheetRoute? {
        presentation(at: level)?.route
    }

    /// The presentation at a level, or nil. `SheetLayer` binds it.
    func presentation(at level: Int) -> SheetPresentation? {
        presentations.indices.contains(level) ? presentations[level] : nil
    }

    /// Closes the sheet at the level and each sheet above it, when the system closed the sheet.
    func closeSheets(from level: Int) {
        if presentations.count > level {
            presentations.removeSubrange(level...)
        }
    }

    /// Closes the presentation and each sheet above it, when the system closed it. A presentation that is not open
    /// changes nothing: the navigator already shows other sheets.
    func closeSheets(from presentation: SheetPresentation) {
        if let index = presentations.firstIndex(of: presentation) {
            presentations.removeSubrange(index...)
        }
    }
}
