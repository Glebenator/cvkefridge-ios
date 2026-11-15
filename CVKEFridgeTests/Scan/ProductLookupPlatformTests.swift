import CVKEFridgeFeatures
import Foundation
import Testing
@testable import CVKEFridge

/// The transport and the service of the product lookup. A `URLProtocol` answers in the place of the network, so no
/// test sends a request to a server.
@Suite(.serialized)
struct ProductLookupPlatformTests {
    private static let product = URL(string: "https://world.openfoodfacts.org/api/v2/product/3017620422003?fields=product_name")!
    private static let headers = ["User-Agent": "CVKEFridge-iOS/0.1.0", "Accept": "application/json"]

    private func transport(timeout: TimeInterval = 10, _ answer: @escaping StubProtocol.Answer) -> URLSessionHttpTransport {
        StubProtocol.start(answer)
        return URLSessionHttpTransport(timeout: timeout, protocolClasses: [StubProtocol.self])
    }

    // MARK: - The transport

    @Test func aRequestHasTheHeadersOfTheClientAndNoDataAboutThePerson() async throws {
        let transport = transport { _ in .response(status: 200, body: Data(#"{"status":1}"#.utf8)) }
        let response = try await transport.get(url: Self.product, headers: Self.headers)

        #expect(response.status == 200)
        #expect(String(data: response.body, encoding: .utf8) == #"{"status":1}"#)
        let request = try #require(StubProtocol.requests.first)
        #expect(StubProtocol.requests.count == 1)
        #expect(request.url == Self.product)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "CVKEFridge-iOS/0.1.0")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        // The languages of the person do not go to the server, and the request has no cookie.
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "*")
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(request.httpShouldHandleCookies == false)
        #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
    }

    @Test func anAnswerWithAnErrorStatusIsAnAnswer() async throws {
        let transport = transport { _ in .response(status: 404, body: Data("not found".utf8)) }
        let response = try await transport.get(url: Self.product, headers: Self.headers)
        #expect(response.status == 404)
        #expect(response.body == Data("not found".utf8))
    }

    @Test func onlyHttpsToOpenFoodFactsIsSent() async {
        let transport = transport { _ in .response(status: 200, body: Data()) }
        for text in [
            "http://world.openfoodfacts.org/api/v2/product/3017620422003",
            "https://example.com/api/v2/product/3017620422003",
            "https://world.openfoodfacts.org.example.com/api/v2/product/3017620422003",
            "https://world.openfoodfacts.org:8443/api/v2/product/3017620422003",
            "https://user@world.openfoodfacts.org/api/v2/product/3017620422003",
        ] {
            let url = URL(string: text)!
            #expect(!URLSessionHttpTransport.allows(url))
            await #expect(throws: URLSessionHttpTransport.RefusedURL.self) {
                _ = try await transport.get(url: url, headers: Self.headers)
            }
        }
        #expect(StubProtocol.requests.isEmpty)
        #expect(URLSessionHttpTransport.allows(Self.product))
        #expect(URLSessionHttpTransport.allows(OpenFoodFactsClient.url(barcode: "3017620422003", language: "de")))
        #expect(!URLSessionHttpTransport.allows(nil))
    }

    @Test func aRedirectToADifferentServerIsNotFollowed() async throws {
        let other = URL(string: "https://example.com/api/v2/product/3017620422003")!
        let transport = transport { request in
            request.url == Self.product ? .redirect(to: other) : .response(status: 200, body: Data("other".utf8))
        }
        let response = try await transport.get(url: Self.product, headers: Self.headers)
        // The answer is the redirect itself. The barcode did not go to the other server.
        #expect(response.status == 301)
        #expect(StubProtocol.requests.map(\.url) == [Self.product])
    }

    @Test func aRedirectOnOpenFoodFactsIsFollowed() async throws {
        let moved = URL(string: "https://world.openfoodfacts.org/api/v2/product/03017620422003")!
        let transport = transport { request in
            request.url == Self.product ? .redirect(to: moved) : .response(status: 200, body: Data("moved".utf8))
        }
        let response = try await transport.get(url: Self.product, headers: Self.headers)
        #expect(response.status == 200)
        #expect(response.body == Data("moved".utf8))
    }

    @Test func aLongAnswerIsCut() async throws {
        let long = Data(repeating: 0x61, count: URLSessionHttpTransport.maxBodyBytes + 5000)
        let transport = transport { _ in .response(status: 200, body: long) }
        let response = try await transport.get(url: Self.product, headers: Self.headers)
        #expect(response.body.count == URLSessionHttpTransport.maxBodyBytes)
    }

    @Test func theErrorsOfTheSystemBecomeTheErrorsOfTheLookup() async {
        for (code, expected) in [
            (URLError.Code.timedOut, HttpTransportError.timeout),
            (.notConnectedToInternet, .noConnection),
            (.cannotFindHost, .noConnection),
            (.networkConnectionLost, .noConnection),
            (.secureConnectionFailed, .noConnection),
            (.dataNotAllowed, .noConnection),
        ] {
            let transport = transport { _ in .failure(URLError(code)) }
            await #expect(throws: expected) {
                _ = try await transport.get(url: Self.product, headers: Self.headers)
            }
        }
    }

    @Test func aServerThatDoesNotAnswerIsATimeout() async {
        let transport = transport(timeout: 0.3) { _ in .silence }
        await #expect(throws: HttpTransportError.timeout) {
            _ = try await transport.get(url: Self.product, headers: Self.headers)
        }
    }

    @Test func aCancelledTaskStopsTheRequest() async {
        let transport = transport { _ in .silence }
        let task = Task {
            try await transport.get(url: Self.product, headers: Self.headers)
        }
        // The request started.
        while StubProtocol.requests.isEmpty {
            await Task.yield()
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        // The session stopped the request.
        while StubProtocol.stopped == 0 {
            await Task.yield()
        }
    }

    // MARK: - The service

    private func cacheFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "lookup-\(UUID().uuidString).json")
    }

    private static let nutella = #"{"code":"3017620422003","product":{"brands":"Ferrero","product_name":"Nutella","quantity":"400 g"},"status":1}"#

    @Test func theServiceAsksOpenFoodFactsOneTimeAndThenUsesTheCache() async throws {
        let file = cacheFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let transport = CountingTransport { _ in HttpResponse(status: 200, text: Self.nutella) }
        let service = OpenFoodFactsLookupService(cacheFile: file, transport: transport, version: "0.1.0", language: { "en" })

        let first = try await service.find(["3017620422003"])
        #expect(first.barcode == "3017620422003")
        guard case .found(let product) = first.result else {
            Issue.record("The product was not found")
            return
        }
        #expect(product.name == "Nutella")
        let request = try #require(transport.requests.value.first)
        #expect(request.url.absoluteString.hasPrefix("https://world.openfoodfacts.org/api/v2/product/3017620422003?fields="))
        #expect(request.headers["User-Agent"] == "CVKEFridge-iOS/0.1.0")
        #expect(URLSessionHttpTransport.allows(request.url))

        // The second lookup needs no network, also in a new service with the same file.
        let again = OpenFoodFactsLookupService(cacheFile: file, transport: transport, version: "0.1.0", language: { "en" })
        #expect(try await again.find(["3017620422003"]) == first)
        #expect(transport.requests.value.count == 1)
        // The cache stays on the phone: it is not in the backup.
        #expect(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func eightTypedDigitsFindTheCachedProductOfTheSecondBarcodeWithNoNetwork() async throws {
        let file = cacheFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let transport = CountingTransport { _ in HttpResponse(status: 200, text: Self.nutella) }
        let service = OpenFoodFactsLookupService(cacheFile: file, transport: transport, version: "0.1.0", language: { "en" })
        // A scan of the UPC-E put the product into the cache.
        _ = try await service.find(["0012345000065"])
        #expect(transport.requests.value.count == 1)

        // The same eight digits, typed: they are an EAN-8 and a UPC-E.
        let candidates = Barcodes.typedCandidates("01234565")
        #expect(candidates == ["01234565", "0012345000065"])
        let answer = try await service.find(candidates)
        #expect(answer.barcode == "0012345000065")
        #expect(transport.requests.value.count == 1)
    }

    @Test func theNetworkGetsOnlyTheFirstBarcodeAndAFailureIsNotKept() async throws {
        let file = cacheFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let transport = CountingTransport { _ in throw HttpTransportError.noConnection }
        let service = OpenFoodFactsLookupService(cacheFile: file, transport: transport, version: "0.1.0", language: { "en" })

        let answer = try await service.find(["01234565", "0012345000065"])
        #expect(answer == ProductLookupAnswer(barcode: "01234565", result: .failed(.noConnection)))
        #expect(transport.requests.value.map(\.url.lastPathComponent) == ["01234565"])
        // The service does not try again by itself. The next lookup of the person asks the network again.
        _ = try await service.find(["01234565", "0012345000065"])
        #expect(transport.requests.value.count == 2)
    }
}

/// A transport that records its requests and gives one answer.
private final class CountingTransport: HttpTransport {
    struct Request: Sendable {
        let url: URL
        let headers: [String: String]
    }

    let requests = Locked<[Request]>([])
    private let answer: @Sendable (URL) throws -> HttpResponse

    init(_ answer: @escaping @Sendable (URL) throws -> HttpResponse) {
        self.answer = answer
    }

    func get(url: URL, headers: [String: String]) async throws -> HttpResponse {
        requests.update { $0.append(Request(url: url, headers: headers)) }
        return try answer(url)
    }
}

/// A value that a test changes from more than one thread.
private final class Locked<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        lock.withLock { stored }
    }

    func update(_ change: (inout Value) -> Void) {
        lock.withLock { change(&stored) }
    }
}

/// Answers the requests of a `URLSession` in the place of the network.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    enum Reply: Sendable {
        case response(status: Int, body: Data)
        case redirect(to: URL)
        case failure(URLError)
        /// No answer. The request waits until the session stops it.
        case silence
    }

    typealias Answer = @Sendable (URLRequest) -> Reply

    private static let answer = Locked<Answer?>(nil)
    private static let seen = Locked<[URLRequest]>([])
    private static let stops = Locked<Int>(0)

    /// The requests that arrived, in their order.
    static var requests: [URLRequest] { seen.value }
    /// The number of requests that the session stopped.
    static var stopped: Int { stops.value }

    /// Sets the answer of the next requests, and forgets the requests of the test before.
    static func start(_ answer: @escaping Answer) {
        self.answer.update { $0 = answer }
        seen.update { $0 = [] }
        stops.update { $0 = 0 }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.seen.update { $0.append(request) }
        guard let url = request.url, let reply = Self.answer.value?(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        switch reply {
        case .response(let status, let body):
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) else {
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case .redirect(let target):
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: 301,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": target.absoluteString]
            ) else {
                return
            }
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            // When the session does not follow the redirect, the redirect is the answer of the request.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .silence:
            break
        }
    }

    override func stopLoading() {
        Self.stops.update { $0 += 1 }
    }
}
