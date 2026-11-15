import CVKEFridgeFeatures
import SwiftUI

/// The screen of one food: the product with its batches. PLACEHOLDER: this file shows the values in a plain list.
/// The Food agent replaces the body. The signature `FoodScreen(productId:)` stays.
///
/// Contract:
/// - The screen opens in the navigation stack of a tab (`Route.food`). It sets its navigation title and its toolbar
///   items, and it does not make a `NavigationStack`.
/// - `FoodDetail.of(content.inventory, productId:, today: content.today)` gives the product and its active batches
///   in the use-first order. Nil means that the product is not in the inventory: another action deleted it.
/// - The history of the food is `content.history.lines.filter { $0.productId == productId }`.
/// - Edit: `navigator.present(.editProduct(productId:))` and `navigator.present(.editBatch(batchId:))`.
///   "Add a batch" and "Add again": `navigator.present(.addFood(productId: productId, again: true))`.
/// - Used and thrown away: `TakeRequest` and `TakeSource`, then `model.perform(.take(…))`. "Still good?":
///   `LaterExpiry` and `model.perform(.moveExpiry(batchId:date:))`, with `DatePickerSheet` for "Other date" (give the
///   day after today or after the expiry date as `earliest`). Delete: `model.perform(.deleteBatches(…))` and
///   `model.perform(.deleteProduct(productId:))`. Each message with "Undo" comes from the model.
/// - The note: `model.perform(.saveProduct(…))` with the product and its new note (`Notes.clean`). The message
///   "Note of … saved" or "Note of … removed" with "Undo" comes from the model.
/// - The photo: `model.photos[productId]`, `model.photoImports.contains(productId)`, `PhotoSourceButtons`,
///   `model.setPhoto(productId:picture:)`, and `model.removePhoto(productId:)`. A changed and a removed photo have a
///   message with "Undo".
/// - Words: `Wording.expiry(daysLeft:expiry:)`, `Wording.dateWithSource(_:)`, `Wording.dateAdded(_:)`,
///   `Wording.batchCount(_:)`, `Wording.quantity(_:unit:)`, and `Wording.areaName(id:name:)`.
struct FoodScreen: View {
    let productId: String

    @Environment(FridgeModel.self) private var model
    @Environment(Navigator.self) private var navigator

    var body: some View {
        List {
            InventoryGate { content in
                if let detail = FoodDetail.of(content.inventory, productId: productId, today: content.today) {
                    rows(detail)
                } else {
                    Text(verbatim: RejectionReason.unknownProduct.message)
                }
            }
        }
        .navigationTitle("Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: AppIcon.edit.symbol) {
                    navigator.present(.editProduct(productId: productId))
                }
                .accessibilityIdentifier("food_edit")
            }
        }
        .accessibilityIdentifier("food_screen")
    }

    @ViewBuilder
    private func rows(_ detail: FoodDetail) -> some View {
        let product = detail.product
        Section {
            HStack(spacing: Space.s3) {
                ProductImage(productId: product.id, category: product.category, size: 56)
                VStack(alignment: .leading) {
                    Text(verbatim: product.name)
                        .font(Typography.sectionTitle)
                        .accessibilityIdentifier("food_name")
                    Text(verbatim: "\(product.category.label) \(Wording.separator) \(Wording.quantity(detail.total, unit: product.unit))")
                        .font(Typography.secondary)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
            }
            PhotoSourceButtons(
                hasPhoto: model.photos[product.id] != nil,
                isBusy: model.photoImports.contains(product.id),
                onPicture: { model.setPhoto(productId: product.id, picture: $0) },
                onRemove: { model.removePhoto(productId: product.id) }
            )
            if let note = product.note {
                Text(verbatim: note)
            }
        }
        Section {
            if detail.batches.isEmpty {
                Text("You have none of this food now")
            }
            ForEach(detail.batches, id: \.id) { batch in
                Button {
                    navigator.present(.editBatch(batchId: batch.id))
                } label: {
                    VStack(alignment: .leading) {
                        Text(verbatim: Wording.quantity(batch.quantity, unit: product.unit))
                            .foregroundStyle(Palette.onSurface)
                        StatusLabel(
                            verbatim: Wording.expiry(daysLeft: batch.daysLeft, expiry: batch.expiry),
                            freshness: batch.freshness
                        )
                        if let expiry = batch.expiry {
                            Text(verbatim: Wording.dateWithSource(expiry))
                                .font(Typography.secondary)
                                .foregroundStyle(Palette.onSurfaceVariant)
                        }
                    }
                }
                .accessibilityIdentifier("batch_\(batch.id)")
            }
            Button("Add a batch", systemImage: AppIcon.add.symbol) {
                navigator.present(.addFood(productId: product.id, again: true))
            }
            .accessibilityIdentifier("food_add_batch")
        } header: {
            Text(verbatim: Wording.batchCount(detail.batches.count))
        }
        Section {
            Button("Delete food", systemImage: AppIcon.delete.symbol, role: .destructive) {
                model.perform(.deleteProduct(productId: product.id))
                navigator.pop()
            }
            .accessibilityIdentifier("food_delete")
        }
    }
}
