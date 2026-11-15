import Foundation

// The products that a lookup found, on the phone. The Android file
// `app/src/main/java/com/cvke/fridge/lookup/ProductLookupCache.kt` in cvkefridge-android has the same behaviour, with
// one correction (a file that cannot be read now is not replaced).

/// The products that a lookup found, on the phone, so that the second scan of a barcode needs no connection. Only a
/// product that was found goes into the cache. "Not found" and a failed lookup do not go into it.
///
/// The cache is one JSON file in the files of the app. It is not in the backup, so it stays on the phone. A write
/// makes a new file and then replaces the old file. The cache is not necessary for the inventory: when the file
/// cannot be read or written, the app continues without the cache.
///
/// A file that is not there or that is damaged is an empty cache, and the next write replaces it. A file that the
/// cache cannot read now, for example while the phone is locked, is not replaced: the cache reads it again at the
/// next call.
public actor ProductLookupCache {
    /// The largest number of products at the start.
    public static let defaultMaxSize = 1000

    private let file: URL
    private let now: @Sendable () -> Date
    private let maxSize: Int

    /// The products of the file, in the order in which they were saved. Nil until the first read.
    private var entries: [CachedProduct]?

    /// - Parameters:
    ///   - file: The JSON file of the cache. Its folder must exist.
    ///   - now: The instant of now.
    ///   - maxSize: The largest number of products. A new product then replaces the product that was saved first. It
    ///     must be 1 or more.
    public init(file: URL, now: @escaping @Sendable () -> Date = Date.init, maxSize: Int = defaultMaxSize) {
        precondition(maxSize >= 1, "The cache must have space for one product")
        self.file = file
        self.now = now
        self.maxSize = maxSize
    }

    /// The product of the barcode, or nil when the cache does not have it.
    public func get(_ barcode: String) -> LookedUpProduct? {
        load()?.last(where: { $0.barcode == barcode })?.product
    }

    /// Adds or replaces the product of the barcode. The product is then the newest in the cache.
    public func put(_ barcode: String, _ product: LookedUpProduct) {
        guard var all = load() else {
            // The file is there, but the cache cannot read it now. A write would remove its products.
            return
        }
        all.removeAll(where: { $0.barcode == barcode })
        all.append(
            CachedProduct(
                barcode: barcode,
                name: product.name,
                brands: product.brands,
                quantity: product.quantity,
                categories: product.categories,
                savedAt: Int((now().timeIntervalSince1970 * 1000).rounded(.down)),
                storageText: product.storageText
            )
        )
        if all.count > maxSize {
            all.removeFirst(all.count - maxSize)
        }
        entries = all
        write(all)
    }

    /// The products in memory, or the products of the file. Nil when the file is there and cannot be read now.
    private func load() -> [CachedProduct]? {
        if let entries {
            return entries
        }
        let loaded: [CachedProduct]
        do {
            let data = try Data(contentsOf: file)
            loaded = (try? JSONDecoder().decode(CacheFile.self, from: data))?.products ?? []
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            loaded = []
        } catch {
            if !FileManager.default.fileExists(atPath: file.path) {
                loaded = []
            } else {
                return nil
            }
        }
        // A barcode that is in the file two times keeps its last product, in the place of that product.
        var seen = Set<String>()
        var unique: [CachedProduct] = []
        for product in loaded.reversed() where seen.insert(product.barcode).inserted {
            unique.append(product)
        }
        let products = Array(unique.reversed())
        entries = products
        return products
    }

    private func write(_ products: [CachedProduct]) {
        do {
            let data = try JSONEncoder().encode(CacheFile(products: products))
            try data.write(to: file, options: .atomic)
            Self.excludeFromBackup(file)
        } catch {
            // The products stay in memory while the app runs. The next write tries again.
        }
    }

    private static func excludeFromBackup(_ file: URL) {
        #if canImport(Darwin)
        var url = file
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        #endif
    }
}

/// The JSON shape of the file: `{"products": [...]}`.
private struct CacheFile: Codable {
    let products: [CachedProduct]
}

/// One product of the file. `savedAt` is the instant of the lookup, in milliseconds from 1970-01-01T00:00:00Z. A
/// product that an earlier version of the app saved has no storage text. Unknown keys have no effect.
private struct CachedProduct: Codable {
    let barcode: String
    let name: String
    let brands: String?
    let quantity: String?
    let categories: [String]
    let savedAt: Int
    let storageText: String?

    init(
        barcode: String,
        name: String,
        brands: String?,
        quantity: String?,
        categories: [String],
        savedAt: Int,
        storageText: String?
    ) {
        self.barcode = barcode
        self.name = name
        self.brands = brands
        self.quantity = quantity
        self.categories = categories
        self.savedAt = savedAt
        self.storageText = storageText
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        barcode = try container.decode(String.self, forKey: .barcode)
        name = try container.decode(String.self, forKey: .name)
        brands = try container.decodeIfPresent(String.self, forKey: .brands)
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity)
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        savedAt = try container.decode(Int.self, forKey: .savedAt)
        storageText = try container.decodeIfPresent(String.self, forKey: .storageText)
    }

    var product: LookedUpProduct {
        LookedUpProduct(name: name, brands: brands, quantity: quantity, categories: categories, storageText: storageText)
    }
}
