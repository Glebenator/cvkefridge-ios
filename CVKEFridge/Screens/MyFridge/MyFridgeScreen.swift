import CVKEFridgeFeatures
import SwiftUI

/// My Fridge, the second tab. PLACEHOLDER: this file shows the rows in a plain list, with the swipe actions, so that
/// the app works from end to end. The My Fridge agent replaces the body. The signature `MyFridgeScreen()` stays.
///
/// Contract:
/// - The screen is the first screen of the navigation stack of the My Fridge tab. It sets its navigation title, and
///   it does not make a `NavigationStack`.
/// - The filters and the search text are `navigator.myFridgeFilter` (a `FoodFilter`). Read and write it there: Home
///   and a reminder open My Fridge with a filter. The sort order is the state of this screen, and it stays when the
///   filter changes.
/// - `navigator.myFridgeRestarts` changes each time My Fridge starts again (a tap on its tab while it is selected, a
///   count of Home, a reminder). The screen then closes its search field and scrolls to the top.
/// - The rows are `content.overview.filtered(filter, categoryLabel: Wording.categoryLabel, unitLabel:
///   Wording.unitLabel)`, in the order of `InventoryContent.sort(_:key:ascending:categoryLabel:)`.
/// - The storage areas are `content.overview.areas`, with "All" (`Wording.allAreas`) first. Use
///   `AreaSummary.displayName`.
/// - A tap on a row calls `navigator.open(.food(productId:))`.
/// - A swipe records the batch to use first: `model.perform(.take(…))` with `row.firstQuantity`. "Used…" and
///   "Thrown away…" of the menu ask for a quantity (`TakeRequest`, `TakeSource`). The message with "Undo" comes from
///   the model.
/// - The menu of the screen has "Manage storage areas": `navigator.open(.storageAreas)`.
/// - The empty state has "Scan a barcode" (`navigator.scan()`) and "Add by hand" (`navigator.addFood()`).
struct MyFridgeScreen: View {
    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator

    var body: some View {
        @Bindable var navigator = navigator
        List {
            InventoryGate { content in
                let overview = content.overview
                let filtered = overview.filtered(
                    navigator.myFridgeFilter,
                    categoryLabel: Wording.categoryLabel,
                    unitLabel: Wording.unitLabel
                )
                if overview.sample {
                    SampleBanner()
                }
                Picker("Storage area", selection: $navigator.myFridgeFilter.areaId) {
                    Text(verbatim: Wording.allAreas).tag(String?.none)
                    ForEach(overview.areas, id: \.id) { area in
                        Text(verbatim: area.displayName).tag(String?.some(area.id))
                    }
                }
                .accessibilityIdentifier("area_picker")
                if filtered.rows.isEmpty {
                    Text("No matching items")
                }
                ForEach(filtered.rows, id: \.key) { row in
                    Button {
                        navigator.open(.food(productId: row.productId))
                    } label: {
                        HStack(spacing: Space.s3) {
                            ProductImage(productId: row.productId, category: row.category)
                            VStack(alignment: .leading) {
                                Text(verbatim: row.name)
                                    .foregroundStyle(Palette.onSurface)
                                Text(verbatim: "\(Wording.quantity(row.quantity, unit: row.unit)) \(Wording.separator) \(Wording.expiry(daysLeft: row.daysLeft, expiry: row.expiry))")
                                    .font(Typography.secondary)
                                    .foregroundStyle(row.freshness.color)
                            }
                        }
                    }
                    .accessibilityIdentifier("food_\(row.productId)")
                    .swipeActions(edge: .leading) {
                        Button("Used", systemImage: AppIcon.check.symbol) { take(row, .used) }
                            .tint(Palette.primary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Thrown away", systemImage: AppIcon.delete.symbol) { take(row, .thrownAway) }
                            .tint(Palette.tertiary)
                    }
                }
            }
        }
        .searchable(text: $navigator.myFridgeFilter.query, prompt: Text("Search items"))
        .navigationTitle("My Fridge")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More actions", systemImage: AppIcon.more.symbol) {
                    Button("Scan a barcode", systemImage: AppIcon.scan.symbol) { navigator.scan() }
                        .accessibilityIdentifier("menu_scan")
                    Button("Manage storage areas", systemImage: AppIcon.edit.symbol) { navigator.open(.storageAreas) }
                        .accessibilityIdentifier("menu_manage_areas")
                }
                .accessibilityIdentifier("my_fridge_menu")
            }
        }
        .accessibilityIdentifier("my_fridge_screen")
    }

    private func take(_ row: FoodRow, _ outcome: Outcome) {
        model.perform(
            .take(.init(productId: row.productId, batchIds: row.batchIds, quantity: row.firstQuantity, outcome: outcome))
        )
    }
}
