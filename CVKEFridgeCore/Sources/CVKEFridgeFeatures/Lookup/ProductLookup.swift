import Foundation

// The product lookup: first the cache, then Open Food Facts. The Android file
// `app/src/main/java/com/cvke/fridge/lookup/ProductLookup.kt` in cvkefridge-android has the same behaviour, with one
// correction (the limit uses a monotonic clock).

/// The product lookup: first the cache on the phone, then Open Food Facts. A found product goes into the cache. A
/// product that is not found and a failed lookup do not, so the next scan asks Open Food Facts again.
///
/// The app never sends a lookup again by itself. Only the person can do that. As a second protection for the server,
/// the app sends not more than `maxRequests` requests in `window`. A person who scans does not get to this number.
/// Open Food Facts permits more.
///
/// The limit uses a monotonic clock. A change of the clock of the device has no effect on it.
public actor ProductLookup {
    /// The largest number of requests in `window`.
    public static let maxRequests = 30
    /// The time of the limit.
    public static let window: Duration = .seconds(60)

    private let client: OpenFoodFactsClient
    private let cache: ProductLookupCache
    private let language: @Sendable () -> String
    private let now: @Sendable () -> ContinuousClock.Instant

    /// The instants of the requests in the last `window`, oldest first.
    private var sent: [ContinuousClock.Instant] = []

    /// - Parameters:
    ///   - language: The language code of the device, for example "en".
    ///   - now: The instant of now on a monotonic clock.
    public init(
        client: OpenFoodFactsClient,
        cache: ProductLookupCache,
        language: @escaping @Sendable () -> String,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.client = client
        self.cache = cache
        self.language = language
        self.now = now
    }

    /// Looks up the product of the `barcode`, in the form of `Barcodes`.
    ///
    /// - Throws: `CancellationError` when the task is cancelled.
    public func find(_ barcode: String) async throws(CancellationError) -> LookupResult {
        if let product = await cache.get(barcode) {
            return .found(product)
        }
        if !mayRequest() {
            return .failed(.busy)
        }
        let result = try await client.lookUp(barcode: barcode, language: language())
        if case .found(let product) = result {
            await cache.put(barcode, product)
        }
        return result
    }

    /// True when a request can go now. Then it counts the request.
    private func mayRequest() -> Bool {
        let time = now()
        // An instant before the last request can only come from a clock that went back. Then the old instants have
        // no meaning, and they must not stop the lookups.
        if let last = sent.last, time < last {
            sent.removeAll()
        }
        while let first = sent.first, first.duration(to: time) >= Self.window {
            sent.removeFirst()
        }
        if sent.count >= Self.maxRequests {
            return false
        }
        sent.append(time)
        return true
    }
}
