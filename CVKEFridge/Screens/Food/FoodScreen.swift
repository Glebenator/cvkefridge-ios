import CVKEFridgeFeatures
import SwiftUI

/// The screen of one food: the product, and its batches in the use-first order. It takes the place of
/// `ui/FoodDetailScreen.kt` of the Android app, with the same contents in the same order:
///
/// 1. The product: its photo or the icon of its category, its name in full, and its category with the sum of its
///    batches (`FoodHeader`). The photo controls are below.
/// 2. The note of the product, or "Add a note" (`FoodNoteRow`). A small sheet edits the note.
/// 3. "Used" and "Thrown away" for the whole food. They take from the batch to use first.
/// 4. The batches (`BatchCard`), and "Add a batch". A food with no active batch says so and has "Add again".
/// 5. The storage tips (`StorageAdviceCard`), below the batches, so that "Used" and "Thrown away" stay near the top.
/// 6. The history of the food (`FoodHistorySection`).
///
/// The toolbar has "Edit food", and a menu with "Delete food", because a delete is for a mistake. The person can
/// undo each action from the message: the model makes the message, and the message gives the haptic signal of the
/// action. So this screen adds no second signal.
///
/// The screen opens in the navigation stack of a tab (`Route.food`). The title of the navigation bar is the name of
/// the food. It shows when the name on the screen went up below the bar, as the titles of the system apps do. Before
/// the inventory is loaded, the title is "Food".
///
/// When the product is not in the inventory, for example after "Delete food" or after an "Undo" of its add, the
/// screen closes. It shows its last content while it closes.
struct FoodScreen: View {
    let productId: String

    /// The name of the coordinate space of the content of the scroll view.
    nonisolated static let contentSpace = "food_content"

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator

    /// The request for "Used" or "Thrown away". The shared modifier `takeQuantity` asks for the quantity.
    @State private var take: TakeRequest?
    /// The batch that gets "Other date" of "Still good?", while the calendar is open.
    @State private var laterDate: LaterDateRequest?
    @State private var editsNote = false
    @State private var showsAllHistory = false
    /// The last content of the screen. The screen shows it while it closes after the product went away.
    @State private var lastDetail: FoodDetail?
    /// The bottom edge of the name of the food, in the content of the scroll view.
    @State private var nameBottom = CGFloat.infinity
    /// True when the name of the food is above the visible part of the screen.
    @State private var nameIsHidden = false
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        let content = model.content
        let current = content.flatMap { FoodDetail.of($0.inventory, productId: productId, today: $0.today) }
        let detail = current ?? lastDetail
        // The inventory is loaded, and the product is not in it: another action deleted it.
        let gone = content != nil && current == nil
        ScrollView {
            InventoryGate { content in
                if let detail {
                    page(detail, content)
                        .allowsHitTesting(!gone)
                }
            }
            .padding(.horizontal, Space.screenMargin)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s6)
            .contentWidth()
            .coordinateSpace(.named(Self.contentSpace))
        }
        .background(Palette.surface.ignoresSafeArea())
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > nameBottom
        } action: { _, hidden in
            nameIsHidden = hidden
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.height
        } action: { _, height in
            viewportHeight = height
        }
        .navigationTitle(detail.map { Text(verbatim: $0.product.name) } ?? Text("Food"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let detail {
                ToolbarItem(placement: .principal) {
                    Text(verbatim: detail.product.name)
                        .font(.headline)
                        .lineLimit(1)
                        .opacity(nameIsHidden ? 1 : 0)
                        .motion(Motion.selection, value: nameIsHidden)
                        // The name on the screen is the heading. VoiceOver does not need the name two times.
                        .accessibilityHidden(true)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        navigator.present(.editProduct(productId: productId))
                    } label: {
                        Label("Edit food", icon: .edit)
                    }
                    .accessibilityIdentifier("food_edit")
                    Menu {
                        Button(role: .destructive) {
                            // The screen closes when the product is not in the inventory. See `close()`.
                            model.perform(.deleteProduct(productId: productId))
                        } label: {
                            Label("Delete food", icon: .delete)
                        }
                        .accessibilityIdentifier("food_delete")
                    } label: {
                        Label("More actions", icon: .more)
                    }
                    .accessibilityIdentifier("food_menu")
                }
            }
        }
        .takeQuantity($take)
        .sheet(item: $laterDate) { request in
            DatePickerSheet("Other date", initial: request.earliest, earliest: request.earliest) { date in
                model.perform(.moveExpiry(batchId: request.batchId, date: date))
            }
        }
        .sheet(isPresented: $editsNote) {
            FoodNoteSheet(productId: productId, note: detail?.product.note) { editsNote = false }
                // While the sheet closes, the message of the save shows below it, above the tab bar.
                .environment(\.noticeHostEnabled, editsNote)
                .presentationSizing(.form)
                .tint(Palette.primary)
        }
        .onChange(of: current, initial: true) { _, current in
            if let current {
                lastDetail = current
            }
        }
        .onChange(of: gone, initial: true) { _, gone in
            if gone {
                close()
            }
        }
        .accessibilityIdentifier("food_screen")
    }

    // MARK: Content

    private func page(_ detail: FoodDetail, _ content: FridgeContent) -> some View {
        let product = detail.product
        let food = product.foodId.flatMap { content.foods.food(id: $0) }
        let advice = StorageAdvices.of(storageText: product.storageText, food: food)
        // The history of the app is calculated off the main actor. This is only the part of this product.
        let history = content.history.lines.filter { $0.productId == productId }
        return VStack(alignment: .leading, spacing: Space.cardGap) {
            FoodHeader(detail: detail, viewportHeight: viewportHeight) { nameBottom = $0 }
                .padding(.bottom, Space.s2)
            FoodNoteRow(note: product.note) { editsNote = true }
            if detail.batches.isEmpty {
                // The core keeps a product when its batches end. "Add again" adds a batch to it.
                EmptyStateView("You have none of this food now") {
                    Button(action: addBatch) {
                        Label("Add again", icon: .add)
                    }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("add_again")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("no_batches")
                .transition(.fade)
            } else {
                batches(detail, content)
            }
            if let advice {
                StorageAdviceCard(advice: advice)
                    .padding(.top, Space.s2)
            }
            if !history.isEmpty {
                FoodHistorySection(lines: history, today: content.today, showsAll: $showsAllHistory)
                    .padding(.top, Space.s4)
            }
        }
        // A batch that goes, comes, or changes its place moves with the list animation.
        .motion(Motion.list, value: detail)
    }

    @ViewBuilder
    private func batches(_ detail: FoodDetail, _ content: FridgeContent) -> some View {
        let ids = detail.batches.map(\.id)
        FoodTakeButtons { outcome in
            take = TakeRequest(productId: productId, batchIds: ids, outcome: outcome)
        }
        .padding(.top, Space.s2)
        Text(verbatim: Wording.batchCount(detail.batches.count))
            .font(Typography.cardTitle)
            .foregroundStyle(Palette.onSurface)
            .contentTransition(.numericText())
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("food_batches")
            .padding(.top, Space.s2)
        ForEach(detail.batches, id: \.id) { batch in
            BatchCard(
                batch: batch,
                unit: detail.product.unit,
                areaName: areaName(of: batch, in: content.inventory),
                // The first batch is the one that a use takes from.
                usesFirst: detail.batches.count > 1 && batch.id == ids.first,
                today: content.today,
                actions: BatchActions(
                    take: { take = TakeRequest(productId: productId, batchIds: [batch.id], outcome: $0) },
                    edit: { navigator.present(.editBatch(batchId: batch.id)) },
                    delete: { model.perform(.deleteBatches(productId: productId, batchIds: [batch.id])) },
                    moveExpiry: { model.perform(.moveExpiry(batchId: batch.id, date: $0)) },
                    pickExpiry: { laterDate = LaterDateRequest(batchId: batch.id, earliest: $0) }
                )
            )
            .transition(.rise)
        }
        Button(action: addBatch) {
            Label("Add a batch", icon: .add)
        }
        .buttonStyle(.outline(.large, fullWidth: true))
        .accessibilityIdentifier("food_add_batch")
        .padding(.top, Space.s2)
    }

    /// The name of the storage area of a batch on the screen. The two fixed storage areas have their names in the
    /// language of the person.
    private func areaName(of batch: BatchLine, in inventory: Inventory) -> String {
        guard let areaId = inventory.batches.first(where: { $0.id == batch.id })?.storageAreaId else {
            return batch.areaName
        }
        return Wording.areaName(id: areaId, name: batch.areaName)
    }

    // MARK: Actions

    /// "Add a batch" and "Add again": the add form, with the storage area of the newest batch and the usual
    /// quantity.
    private func addBatch() {
        navigator.present(.addFood(productId: productId, again: true))
    }

    /// Closes this screen in each tab that shows it, and the small sheets of this screen.
    private func close() {
        take = nil
        laterDate = nil
        editsNote = false
        for tab in AppTab.allCases where navigator.paths[tab]?.contains(.food(productId: productId)) == true {
            navigator.paths[tab]?.removeAll { $0 == .food(productId: productId) }
        }
    }
}

/// The batch that gets "Other date" of "Still good?". `earliest` is the first date that the person can select: the
/// day after the expiry date, or after today when the batch is expired.
private struct LaterDateRequest: Identifiable {
    let batchId: String
    let earliest: CalendarDate

    var id: String { batchId }
}
