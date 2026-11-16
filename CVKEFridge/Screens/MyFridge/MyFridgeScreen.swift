import CVKEFridgeFeatures
import SwiftUI

/// My Fridge, the second tab: the list of all food. It takes the place of `ui/MyFridgeScreen.kt` of the Android app,
/// with the same contents: the storage areas, the search field, the chips for the category and the freshness, the
/// sort order, and one card for each food in each storage area.
///
/// - The screen is the first screen of the navigation stack of the My Fridge tab. It sets its navigation title, and
///   it does not make a `NavigationStack`.
/// - The storage areas are a row of Liquid Glass capsules below the navigation bar: "All", Fridge, Freezer, and then
///   the others by name. The row floats above the list. The search field is the search field of the system.
/// - The filters and the search text are `navigator.myFridgeFilter`, because Home and a reminder open My Fridge
///   with a filter. The sort order is the state of this screen, and it stays when the filter changes.
/// - When My Fridge starts again (`navigator.myFridgeRestarts`), the search field closes and the list goes to the
///   top. A new filter also starts at the top of the list.
/// - The search compares the words on the screen: the name, the category, the unit, the storage area, and the note.
/// - A swipe on a card records the oldest batch as used or as thrown away. The menu of a card asks for a quantity
///   (`takeQuantity`). The message with "Undo" comes from the model.
/// - The menu of the screen opens the scanner and the screen of the storage areas.
struct MyFridgeScreen: View {
    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var sortKey = SortKey.expiry
    @State private var ascending = SortKey.expiry.ascendingFirst
    /// The food that the person records as used or as thrown away with a quantity, or nil.
    @State private var take: TakeRequest?
    /// True while the search field is open.
    @State private var searching = false

    /// The identifier of the first row of the list, for the scroll to the top.
    private static let top = "my_fridge_top"

    var body: some View {
        @Bindable var navigator = navigator
        let overview = model.content?.overview
        let view = overview?.filtered(
            navigator.myFridgeFilter,
            categoryLabel: Wording.categoryLabel,
            unitLabel: Wording.unitLabel
        )
        let rows = view.map { view in
            InventoryContent.sort(view.rows, key: sortKey, ascending: ascending, categoryLabel: Wording.categoryLabel)
        } ?? []
        ScrollViewReader { proxy in
            List {
                if let overview, let view {
                    header(overview, view)
                        .id(Self.top)
                        .plainRow()
                    if view.areaFoodCount == 0 {
                        // All storage areas have no food, or the storage area of the tab has no food.
                        EmptyStateView("No items yet") {
                            AddFoodButtons()
                        }
                        .plainRow()
                    } else if rows.isEmpty {
                        noMatch(view)
                            .plainRow()
                    } else {
                        ForEach(rows, id: \.key) { row in
                            FoodCard(row: row, showsArea: view.areaId == nil) {
                                navigator.open(.food(productId: row.productId))
                            } onAction: { action in
                                act(row, action)
                            }
                            .contentWidth()
                            .foodCardSwipes { action in act(row, action) }
                            .plainRow(top: Space.cardGap / 2, bottom: Space.cardGap / 2)
                        }
                    }
                } else {
                    InventoryGate { _ in EmptyView() }
                        .plainRow()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("my_fridge_screen")
            .scrollDismissesKeyboard(.immediately)
            .animation(Motion.resolved(Motion.list, reduceMotion: reduceMotion), value: rows.map(\.key))
            .safeAreaBar(edge: .top, spacing: 0) {
                if let overview {
                    areaTabs(overview, selected: view?.areaId)
                }
            }
            .onChange(of: navigator.myFridgeFilter) { _, _ in
                // A new filter starts at the top of the list.
                proxy.scrollTo(Self.top, anchor: .top)
            }
            .onChange(of: navigator.myFridgeRestarts) { _, _ in
                searching = false
                proxy.scrollTo(Self.top, anchor: .top)
            }
        }
        .background(Palette.surface.ignoresSafeArea())
        .navigationTitle("My Fridge")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $navigator.myFridgeFilter.query,
            isPresented: $searching,
            // With an accessibility text size, the system starts with the search field above the top of the list,
            // where a person does not see it. The field then always shows.
            placement: dynamicTypeSize.isAccessibilitySize ? .navigationBarDrawer(displayMode: .always) : .automatic,
            prompt: Text("Search items")
        )
        .toolbar { toolbar }
        .takeQuantity($take)
        .onChange(of: view?.areaId) { _, areaId in
            // Another action deleted the storage area of the tab. The tab of all storage areas is then selected,
            // and a new form does not start in a storage area that is not there.
            if view != nil, areaId == nil, navigator.myFridgeFilter.areaId != nil {
                navigator.myFridgeFilter.areaId = nil
            }
        }
    }

    // MARK: The parts above the cards

    /// The storage areas: "All", and then one capsule for each storage area.
    private func areaTabs(_ overview: InventoryContent, selected: String?) -> some View {
        let segments = [GlassSegment(id: String?.none, title: Wording.allAreas)]
            + overview.areas.map { GlassSegment(id: String?.some($0.id), title: $0.displayName) }
        return GlassSegmentedRow(
            segments,
            selection: Binding(
                get: { selected },
                set: { navigator.myFridgeFilter.areaId = $0 }
            ),
            label: "Storage area"
        )
        .padding(.bottom, Space.s1)
        .accessibilityIdentifier("area_tabs")
    }

    /// The note of the sample, and the row of the category chip and the two freshness chips. A chip goes to the next
    /// line when the row is too narrow, for example with large text. The row does not scroll sideways.
    private func header(_ overview: InventoryContent, _ view: FilteredFoods) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            if overview.sample {
                SampleBanner()
            }
            FlowLayout {
                MenuChip("Category", selection: view.category?.label) {
                    categoryOption(nil, label: String(localized: "All categories"), count: view.allCategoriesCount, selected: view.category)
                    ForEach(view.categories, id: \.category) { entry in
                        categoryOption(entry.category, label: entry.category.label, count: entry.foodCount, selected: view.category)
                    }
                }
                .haptic(.selection, trigger: view.category)
                .accessibilityHint(Text("Shows the food of one category."))
                .accessibilityIdentifier("filter_category")
                freshnessChip(.expiring, "Expiring", count: view.expiringCount, identifier: "filter_expiring")
                freshnessChip(.expired, "Expired", count: view.expiredCount, identifier: "filter_expired")
            }
        }
        // With no note of the sample, the chips are the widest part. They stay at the leading edge.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentWidth()
    }

    /// One item of the menu of the categories, with its number of foods. The selected item has a check mark.
    private func categoryOption(
        _ category: CVKEFridgeCore.Category?,
        label: String,
        count: Int,
        selected: CVKEFridgeCore.Category?
    ) -> some View {
        Toggle(isOn: Binding(
            get: { selected == category },
            set: { on in
                if on {
                    navigator.myFridgeFilter.category = category
                }
            }
        )) {
            Text(verbatim: label)
            Text(verbatim: Wording.itemCount(count))
        }
        .accessibilityIdentifier("category_\(category?.rawValue ?? "all")")
    }

    /// A chip that shows or hides the food of one freshness, with the number of foods. The two chips can be on
    /// together. VoiceOver reads "Freshness" with the name and the number.
    private func freshnessChip(_ freshness: Freshness, _ title: LocalizedStringKey, count: Int, identifier: String) -> some View {
        let name = freshness == .expiring ? String(localized: "Expiring") : String(localized: "Expired")
        return FilterChip(
            title,
            count: Wording.number(count),
            isOn: Binding(
                get: { navigator.myFridgeFilter.freshness.contains(freshness) },
                set: { on in
                    if on {
                        navigator.myFridgeFilter.freshness.insert(freshness)
                    } else {
                        navigator.myFridgeFilter.freshness.remove(freshness)
                    }
                }
            )
        )
        .accessibilityLabel(Text("Freshness: \(name), \(Wording.itemCount(count))", comment: "For VoiceOver: a freshness filter and its number of foods, for example \"Freshness: Expiring, 3 items\"."))
        .accessibilityIdentifier(identifier)
    }

    /// There is food, but none for the filters and the search text. The search field has its own button to clear
    /// the text.
    private func noMatch(_ view: FilteredFoods) -> some View {
        ListMessage("No matching items") {
            if view.category != nil || !navigator.myFridgeFilter.freshness.isEmpty {
                Button("Clear filters") {
                    navigator.myFridgeFilter.category = nil
                    navigator.myFridgeFilter.freshness = []
                }
                .buttonStyle(.quiet)
                .accessibilityIdentifier("filter_clear")
            }
        }
    }

    // MARK: The toolbar

    /// The sort order, its direction, and the menu of the screen.
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker(selection: sortSelection) {
                    ForEach(SortKey.allCases, id: \.self) { key in
                        Text(verbatim: key.label)
                            .tag(key)
                            .accessibilityIdentifier("sort_option_\(key.rawValue)")
                    }
                } label: {
                    Text("Sort by")
                }
            } label: {
                Label {
                    Text("Sort by \(sortKey.label)", comment: "For VoiceOver. The value is the sort order, for example \"Expiry\".")
                } icon: {
                    Image(icon: .sort)
                }
            }
            // A menu of the system gives no signal for a new selection. The sort order gets the selection signal,
            // as its direction and the storage areas do.
            .haptic(.selection, trigger: sortKey)
            .accessibilityIdentifier("sort_key")
            Button {
                ascending.toggle()
            } label: {
                Label {
                    ascending ? Text("Ascending order") : Text("Descending order")
                } icon: {
                    Image(icon: ascending ? .ascending : .descending)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .haptic(.selection, trigger: ascending)
            .accessibilityHint(Text("Changes the direction of the sort order."))
            .accessibilityIdentifier("sort_order")
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Menu("More actions", systemImage: AppIcon.more.symbol) {
                Button("Scan a barcode", systemImage: AppIcon.scan.symbol) {
                    navigator.scan()
                }
                .accessibilityIdentifier("menu_scan")
                Button("Storage areas", systemImage: AppIcon.edit.symbol) {
                    navigator.open(.storageAreas)
                }
                .accessibilityIdentifier("menu_storage_areas")
            }
            .accessibilityIdentifier("my_fridge_menu")
        }
    }

    /// The sort order of the menu. A new order starts in its own first direction.
    private var sortSelection: Binding<SortKey> {
        Binding(
            get: { sortKey },
            set: { key in
                if key != sortKey {
                    sortKey = key
                    ascending = key.ascendingFirst
                }
            }
        )
    }

    // MARK: Actions

    private func act(_ row: FoodRow, _ action: FoodCardAction) {
        switch action {
        case .useOldest:
            takeOldest(row, .used)
        case .throwAwayOldest:
            takeOldest(row, .thrownAway)
        case .use:
            take = TakeRequest(productId: row.productId, batchIds: row.batchIds, outcome: .used)
        case .throwAway:
            take = TakeRequest(productId: row.productId, batchIds: row.batchIds, outcome: .thrownAway)
        case .addBatch:
            navigator.present(.addFood(productId: row.productId, again: true))
        case .edit:
            navigator.present(.editProduct(productId: row.productId))
        case .delete:
            model.perform(.deleteBatches(productId: row.productId, batchIds: row.batchIds))
        }
    }

    /// Records all of the batch to use first. It is the action of a swipe, and it needs no question.
    private func takeOldest(_ row: FoodRow, _ outcome: Outcome) {
        model.perform(
            .take(.init(productId: row.productId, batchIds: row.batchIds, quantity: row.firstQuantity, outcome: outcome))
        )
    }
}

private extension View {
    /// A row of the list with no line and no fill of its own, with the margins of the screen. The cards and the
    /// parts above them have their own surfaces.
    func plainRow(top: CGFloat = Space.s1, bottom: CGFloat = Space.s1) -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: top, leading: Space.screenMargin, bottom: bottom, trailing: Space.screenMargin))
    }
}
