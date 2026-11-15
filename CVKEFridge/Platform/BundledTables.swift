import CVKEFridgeFeatures
import Foundation

/// The two tables of the shared specification that the build puts into the app: `spec/foods.json` and
/// `spec/storage-hints.json` (see `project.yml`). The app reads them off the main actor.
enum BundledTables {
    /// A table is not in the app.
    struct Missing: Error, Sendable {
        let name: String
    }

    /// The table of foods, for the expiry estimate and the suggestions.
    ///
    /// - Throws: An error when the file is not in the app, cannot be read, or is not a table of foods.
    @concurrent static func foods(in bundle: Bundle = .main) async throws -> FoodTable {
        try FoodTable.decode(text(of: "foods", in: bundle))
    }

    /// The table for the storage hint of a looked-up product.
    ///
    /// - Throws: An error when the file is not in the app, cannot be read, or is not a table of storage hints.
    @concurrent static func storageHints(in bundle: Bundle = .main) async throws -> StorageHints {
        try StorageHints.decode(text(of: "storage-hints", in: bundle))
    }

    private static func text(of name: String, in bundle: Bundle) throws -> String {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw Missing(name: name)
        }
        return String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }
}
