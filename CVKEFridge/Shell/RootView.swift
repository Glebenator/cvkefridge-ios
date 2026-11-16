import CVKEFridgeFeatures
import SwiftUI

/// The app: the tab bar with Home, My Fridge, History, and Settings, the add button at the tab bar, the sheets, and
/// the place of the messages. It takes the place of `ui/FridgeApp.kt` and `ui/TabsScreen.kt` of the Android app.
///
/// - Each tab has its own navigation stack. Food and Storage areas open in the stack of the selected tab.
/// - The add button is the separate Liquid Glass button at the end of the tab bar. It is not a destination: a tap
///   opens the form that adds food as a sheet, from each tab, and the selected tab stays.
/// - A tap on the tab that is selected goes back to its first screen. For My Fridge it also starts My Fridge again
///   (see `Navigator.select`).
/// - A tap on a reminder closes the sheets and shows My Fridge with the expiring and the expired food.
/// - The selected tab comes back after the system stopped the app in the background.
struct RootView: View {
    /// What the tab bar can select: a tab, or the add button.
    private enum Selection: Hashable {
        case tab(AppTab)
        case add
    }

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("root.tab") private var storedTab = AppTab.home.rawValue

    /// False when the app must start on Home each time, for the UI tests.
    var restoresTab = true

    var body: some View {
        TabView(selection: selection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.icon.symbol, value: Selection.tab(.home)) {
                TabStack(tab: .home) { HomeScreen() }
            }
            .accessibilityIdentifier(AppTab.home.identifier)
            Tab(AppTab.myFridge.title, systemImage: AppTab.myFridge.icon.symbol, value: Selection.tab(.myFridge)) {
                TabStack(tab: .myFridge) { MyFridgeScreen() }
            }
            .accessibilityIdentifier(AppTab.myFridge.identifier)
            Tab(AppTab.history.title, systemImage: AppTab.history.icon.symbol, value: Selection.tab(.history)) {
                TabStack(tab: .history) { HistoryScreen() }
            }
            .accessibilityIdentifier(AppTab.history.identifier)
            Tab(AppTab.settings.title, systemImage: AppTab.settings.icon.symbol, value: Selection.tab(.settings)) {
                TabStack(tab: .settings) { SettingsScreen() }
            }
            .accessibilityIdentifier(AppTab.settings.identifier)
            // The role gives the button its own place at the end of the tab bar. The selection never changes to
            // it: see `selection`.
            Tab("Add food", systemImage: AppIcon.add.symbol, value: Selection.add, role: .search) {
                Palette.surface.ignoresSafeArea()
            }
            .accessibilityIdentifier("add_food")
        }
        .modifier(SheetLayer(level: 0))
        .background(Palette.surface.ignoresSafeArea())
        .onAppear {
            if restoresTab, let tab = AppTab(rawValue: storedTab), tab != navigator.tab {
                navigator.select(tab)
            }
        }
        .onChange(of: navigator.tab) { _, tab in
            storedTab = tab.rawValue
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // The date can be a new date, and the person can come back from the Settings app.
                model.refreshToday()
                model.refreshNotificationAccess()
            }
        }
        .onChange(of: model.showRequest, initial: true) { _, request in
            if let request {
                navigator.showAttention(request.freshness)
                model.showRequestDone(request.id)
            }
        }
        .onChange(of: navigator.sheets) { _, sheets in
            // A lookup stops when the scanner closes. It does not stop when the add form opens above the scanner.
            if !sheets.contains(where: { if case .scan = $0 { true } else { false } }) {
                model.cancelLookup()
            }
        }
    }

    /// The selection of the tab bar. The add button opens the add form, and the selected tab stays as it is.
    private var selection: Binding<Selection> {
        Binding(
            get: { .tab(navigator.tab) },
            set: { selection in
                switch selection {
                case .tab(let tab):
                    navigator.select(tab)
                case .add:
                    navigator.addFood()
                }
            }
        )
    }
}

/// The navigation stack of one tab, with the screens of the routes and the place of the messages above the tab bar.
private struct TabStack<Root: View>: View {
    let tab: AppTab
    @ViewBuilder let root: Root

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(NoticeStage.self) private var stage

    var body: some View {
        NavigationStack(path: path) {
            root
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                        // After a tap on the add button of the tab bar, the navigation bar of this stack can make
                        // the bar of a new screen in a place that does not get the environment of the app. The
                        // screen then did not find the model and stopped the app. So each screen of the stack
                        // gets the objects of the app again here.
                        .environment(model)
                        .environment(navigator)
                        .environment(stage)
                }
        }
        .noticeHost()
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .food(let productId):
            FoodScreen(productId: productId)
        case .storageAreas:
            StorageAreasScreen()
        }
    }

    /// The screens above the first screen of this tab.
    private var path: Binding<[Route]> {
        Binding(
            get: { navigator.paths[tab] ?? [] },
            set: { navigator.paths[tab] = $0 }
        )
    }
}
