import CVKEFridgeFeatures
import Foundation
import Testing

/// The cache on the phone, and the product lookup that uses it before the network. The Android test
/// `ProductLookupTest` has the same cases. The last tests are for the corrections of the iOS port.
struct ProductLookupTests {
    private let nutella = LookedUpProduct(name: "Nutella", brands: "Ferrero, Nutella", quantity: "400 g", categories: ["en:spreads"])
    private let cola = LookedUpProduct(name: "Coca-Cola", brands: nil, quantity: "330 ml", categories: ["en:beverages"])
    private let start = ContinuousClock.now
    private let clock: LockedBox<Duration> = LockedBox(.zero)

    private func cache(_ file: URL, maxSize: Int = 1000) -> ProductLookupCache {
        ProductLookupCache(file: file, now: { Date(timeIntervalSince1970: 1) }, maxSize: maxSize)
    }

    private func found(_ name: String) -> FakeTransport.Answer {
        { HttpResponse(status: 200, text: #"{"status":1,"product":{"product_name":"\#(name)"}}"#) }
    }

    private let notFound: FakeTransport.Answer = { HttpResponse(status: 404, text: #"{"status":0}"#) }

    private func lookup(_ server: FakeTransport, cache: ProductLookupCache) -> ProductLookup {
        let start = start
        let clock = clock
        return ProductLookup(
            client: OpenFoodFactsClient(transport: server, userAgent: "test"),
            cache: cache,
            language: { "en" },
            now: { start + clock.value }
        )
    }

    private func name(_ result: LookupResult) -> String? {
        if case .found(let product) = result {
            return product.name
        }
        return nil
    }

    @Test func theCacheKeepsAProductAfterTheAppStopped() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let file = folder.file("lookups.json")
        await cache(file).put("3017620422003", nutella)
        #expect(await cache(file).get("3017620422003") == nutella)
        // The storage text is in the cache also.
        let pizza = LookedUpProduct(name: "Pizza", brands: nil, quantity: nil, categories: ["en:frozen-pizzas"], storageText: "Store at -18°C.")
        await cache(file).put("4006381333931", pizza)
        #expect(await cache(file).get("4006381333931") == pizza)
        #expect(await cache(file).get("5449000000996") == nil)
    }

    @Test func aNewProductReplacesTheProductThatWasSavedFirst() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let file = folder.file("lookups.json")
        let small = cache(file, maxSize: 2)
        await small.put("1", nutella)
        await small.put("2", cola)
        await small.put("1", LookedUpProduct(name: "Nutella 2", brands: nutella.brands, quantity: nutella.quantity, categories: nutella.categories))
        await small.put("3", cola)
        // "2" is now the oldest, because "1" was saved again after it.
        let reopened = cache(file, maxSize: 2)
        #expect(await reopened.get("2") == nil)
        #expect(await reopened.get("1")?.name == "Nutella 2")
        #expect(await reopened.get("3") == cola)
    }

    @Test func aFileThatCannotBeReadIsAnEmptyCache() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let file = folder.file("lookups.json")
        try Data("{not json".utf8).write(to: file)
        let broken = cache(file)
        #expect(await broken.get("3017620422003") == nil)
        await broken.put("3017620422003", nutella)
        #expect(await cache(file).get("3017620422003") == nutella)
    }

    @Test func aSecondLookupOfAFoundProductNeedsNoNetwork() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let server = FakeTransport(found("Nutella"))
        let lookup = lookup(server, cache: cache(folder.file("lookups.json")))
        #expect(name(try await lookup.find("3017620422003")) == "Nutella")
        #expect(name(try await lookup.find("3017620422003")) == "Nutella")
        #expect(server.requestCount == 1)
    }

    @Test func aProductThatIsNotFoundOrAFailedLookupIsNotKept() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let file = folder.file("lookups.json")
        let server = FakeTransport(notFound, { throw HttpTransportError.noConnection }, found("Water"))
        let lookup = lookup(server, cache: cache(file))
        #expect(try await lookup.find("5449000000996") == .notFound)
        #expect(try await lookup.find("5449000000996") == .failed(.noConnection))
        // The third lookup asks the server again, and then the product is in the cache.
        #expect(name(try await lookup.find("5449000000996")) == "Water")
        #expect(server.requestCount == 3)
        #expect(await cache(file).get("5449000000996")?.name == "Water")
        // The atomic write leaves no other file.
        #expect(folder.names() == ["lookups.json"])
    }

    @Test func theAppSendsNotMoreThanThirtyRequestsInOneMinute() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let server = FakeTransport(notFound)
        let lookup = lookup(server, cache: cache(folder.file("lookups.json")))
        for _ in 0..<ProductLookup.maxRequests {
            #expect(try await lookup.find("5449000000996") == .notFound)
        }
        #expect(try await lookup.find("5449000000996") == .failed(.busy))
        #expect(server.requestCount == ProductLookup.maxRequests)
        // One minute after the first request, the app can send again.
        clock.value += ProductLookup.window
        #expect(try await lookup.find("5449000000996") == .notFound)
    }

    // Correction of ProductLookup.kt:21 and :39: the limit used the clock of the device. When that clock went back,
    // the old instants stopped each lookup until the clock came back to them.
    @Test func aClockThatGoesBackDoesNotStopTheLookups() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let server = FakeTransport(notFound)
        let lookup = lookup(server, cache: cache(folder.file("lookups.json")))
        clock.value = .seconds(3600)
        for _ in 0..<ProductLookup.maxRequests {
            _ = try await lookup.find("5449000000996")
        }
        #expect(try await lookup.find("5449000000996") == .failed(.busy))
        clock.value = .seconds(10)
        #expect(try await lookup.find("5449000000996") == .notFound)
    }

    // Correction of ProductLookupCache.kt:53-63: a read that failed for a moment gave an empty cache, and the next
    // write replaced the file and its products.
    @Test func aFileThatCannotBeReadNowIsNotReplaced() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let file = folder.file("lookups.json")
        await cache(file).put("3017620422003", nutella)
        // The file is there, but nothing can read it.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        let locked = cache(file)
        #expect(await locked.get("3017620422003") == nil)
        await locked.put("5449000000996", cola)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        // The products of the file are still there, and the cache reads the file again.
        #expect(await locked.get("3017620422003") == nutella)
        #expect(await cache(file).get("3017620422003") == nutella)
    }

    // Only a file that is surely not there is an empty cache. A folder that cannot be read made `fileExists` false, so
    // the cache kept an empty list in memory and the next write replaced the file.
    @Test func aFolderThatCannotBeReadIsNotAnEmptyCache() async throws {
        let folder = try ScratchFolder()
        defer { folder.remove() }
        let inner = folder.url.appending(path: "cache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        let file = inner.appending(path: "lookups.json", directoryHint: .notDirectory)
        await cache(file).put("3017620422003", nutella)
        // The folder is there, but nothing can open it.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: inner.path)
        let locked = cache(file)
        #expect(await locked.get("3017620422003") == nil)
        await locked.put("5449000000996", cola)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: inner.path)
        // The cache did not keep an empty list: it reads the file now, and the next write keeps its products.
        #expect(await locked.get("3017620422003") == nutella)
        await locked.put("5449000000996", cola)
        #expect(await cache(file).get("3017620422003") == nutella)
        #expect(await cache(file).get("5449000000996") == cola)
    }
}
