import CVKEFridgeFeatures
import SwiftUI

/// The list of the storage areas. PLACEHOLDER: this file shows the storage areas in a plain list. The Storage areas
/// agent replaces the body. The signature `StorageAreasScreen()` stays.
///
/// Contract:
/// - The screen shows in two places: in the navigation stack of My Fridge (`Route.storageAreas`), and in a sheet above
///   a form (`SheetRoute.storageAreas`, with a "Done" button that the shell adds). So it sets its navigation title
///   and its toolbar items, and it does not make a `NavigationStack` and does not close itself.
/// - The storage areas are `content.overview.areas` (Fridge, Freezer, and then the others by name, each with its
///   number of foods) and `content.inventory.storageAreas` (with the kind and `fixed`).
/// - The form of a storage area is `StorageAreaForm`. Save it with `model.perform(.saveStorageArea(…), formToken:)`
///   and read the result with `model.formWrite(token)`. Parts: `StorageKindPicker`, `FieldProblem`,
///   `NameError.areaMessage`.
/// - Delete with `model.perform(.deleteStorageArea(id:))`. The message with "Undo" comes from the model. A storage
///   area with food cannot be deleted: say why before the write (`AreaSummary.foodCount`).
struct StorageAreasScreen: View {
    var body: some View {
        List {
            InventoryGate { content in
                let kinds = Dictionary(uniqueKeysWithValues: content.inventory.storageAreas.map { ($0.id, $0) })
                ForEach(content.overview.areas, id: \.id) { area in
                    LabeledContent {
                        Text(verbatim: Wording.itemCount(area.foodCount))
                    } label: {
                        Label(verbatim: area.displayName, icon: kinds[area.id]?.kind.icon ?? .fridge)
                    }
                    .accessibilityIdentifier("area_\(area.id)")
                }
            }
        }
        .navigationTitle("Storage areas")
        .accessibilityIdentifier("storage_areas_screen")
    }
}
