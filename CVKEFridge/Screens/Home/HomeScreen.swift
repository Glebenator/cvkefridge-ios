import CVKEFridgeFeatures
import SwiftUI

/// Home, the first tab. PLACEHOLDER: this file shows the values in a plain list, so that the app works from end to
/// end. The Home agent replaces the body. The signature `HomeScreen()` stays.
///
/// Contract:
/// - The screen is the first screen of the navigation stack of the Home tab (`RootView` makes the stack). It sets
///   its navigation title, and it does not make a `NavigationStack`.
/// - It reads `FridgeModel` and `Navigator` from the environment.
/// - `content.overview` has all values: `foodCount` ("Total items"), `expiringCount`, `expiredCount`, `attention`
///   (the first batches that need attention, in the use-first order), and `sample` (then show `SampleBanner`).
/// - A tap on the number of expiring or expired batches calls
///   `navigator.showMyFridge(FoodFilter(freshness: [.expiring]))`. "View all" calls `navigator.showMyFridge()`.
/// - A tap on a batch that needs attention calls `navigator.open(.food(productId:))`.
/// - The empty state has "Scan a barcode" (`navigator.scan()`) and "Add by hand" (`navigator.addFood()`).
/// - The offer of reminders reads `model.reminders` and `model.notificationAccess`, and calls
///   `model.requestNotificationAccess()`, `model.setRemindersOn(true, fromOffer: true)`, and
///   `model.dismissReminderOffer()`.
/// - Loading and a failed load: `InventoryGate`.
struct HomeScreen: View {
    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator

    var body: some View {
        List {
            InventoryGate { content in
                let overview = content.overview
                if overview.sample {
                    SampleBanner()
                }
                Section {
                    HStack {
                        Text("Total items")
                        Spacer()
                        Text(verbatim: Wording.number(overview.foodCount))
                            .foregroundStyle(Palette.onSurfaceVariant)
                            .accessibilityIdentifier("hero_total")
                    }
                    Button {
                        navigator.showMyFridge(FoodFilter(freshness: [.expiring]))
                    } label: {
                        LabeledContent("Expiring", value: Wording.number(overview.expiringCount))
                    }
                    .accessibilityIdentifier("metric_expiring")
                    Button {
                        navigator.showMyFridge(FoodFilter(freshness: [.expired]))
                    } label: {
                        LabeledContent("Expired", value: Wording.number(overview.expiredCount))
                    }
                    .accessibilityIdentifier("metric_expired")
                } header: {
                    Text(verbatim: Wording.greeting(at: Date()))
                }
                Section("Needs attention") {
                    if overview.attention.isEmpty {
                        Text("All fresh")
                    }
                    ForEach(overview.attention, id: \.id) { batch in
                        Button {
                            navigator.open(.food(productId: batch.productId))
                        } label: {
                            HStack(spacing: Space.s3) {
                                ProductImage(productId: batch.productId, category: batch.category)
                                VStack(alignment: .leading) {
                                    Text(verbatim: batch.name)
                                    StatusLabel(
                                        verbatim: Wording.expiry(daysLeft: batch.daysLeft, expiry: batch.expiry),
                                        freshness: batch.freshness
                                    )
                                }
                            }
                        }
                        .accessibilityIdentifier("attention_\(batch.id)")
                    }
                    Button("View all") { navigator.showMyFridge() }
                        .accessibilityIdentifier("attention_view_all")
                }
            }
        }
        .navigationTitle("Your Kitchen")
        .accessibilityIdentifier("home_screen")
    }
}
