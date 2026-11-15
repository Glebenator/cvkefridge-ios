import CVKEFridgeFeatures
import Foundation

/// The product lookup of the app: the cache on the phone, and then Open Food Facts (`ProductLookup`).
///
/// The request has the barcode and the names of the fields, and no other data. The User-Agent is
/// `CVKEFridge-iOS/<version>`, as Open Food Facts asks. It has no data about the person.
struct OpenFoodFactsLookupService: ProductLookupService {
    private let cache: ProductLookupCache
    private let lookup: ProductLookup

    /// - Parameters:
    ///   - cacheFile: The JSON file of the cache. Its folder must exist.
    ///   - transport: The connection to the internet. A test gives its own.
    ///   - version: The version name of the app, for the User-Agent.
    ///   - language: The language code of the device, for example "en".
    init(
        cacheFile: URL,
        transport: any HttpTransport = URLSessionHttpTransport(),
        version: String,
        language: @escaping @Sendable () -> String = { Locale.current.language.languageCode?.identifier ?? "en" }
    ) {
        let cache = ProductLookupCache(file: cacheFile)
        self.cache = cache
        lookup = ProductLookup(
            client: OpenFoodFactsClient(transport: transport, userAgent: OpenFoodFactsClient.userAgent(version: version)),
            cache: cache,
            language: language
        )
    }

    func find(_ barcodes: [String]) async throws(CancellationError) -> ProductLookupAnswer {
        // Eight typed digits can be two barcodes. A product that the cache has for one of them needs no network.
        for barcode in barcodes {
            if let product = await cache.get(barcode) {
                return ProductLookupAnswer(barcode: barcode, result: .found(product))
            }
        }
        guard let first = barcodes.first else {
            return ProductLookupAnswer(barcode: "", result: .notFound)
        }
        return ProductLookupAnswer(barcode: first, result: try await lookup.find(first))
    }
}
