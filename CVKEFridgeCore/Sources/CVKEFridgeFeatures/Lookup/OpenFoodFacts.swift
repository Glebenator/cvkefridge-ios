import Foundation

// The client of the product API of Open Food Facts, and the reader of its answers. The Android file
// `app/src/main/java/com/cvke/fridge/lookup/OpenFoodFacts.kt` in cvkefridge-android has the same behaviour.

/// A product from Open Food Facts, with only the fields that the app uses.
public struct LookedUpProduct: Hashable, Sendable {
    /// The name of the product, with no brand. It is not empty.
    public let name: String
    /// The brands as Open Food Facts gives them: names with a comma between them. Nil when there are none.
    public let brands: String?
    /// The quantity of the package as text, for example "400 g". Nil when there is none.
    public let quantity: String?
    /// The category tags of Open Food Facts, for example "en:sweet-spreads".
    public let categories: [String]
    /// The text on the package about how to keep the product, for example "Store at -18°C". Nil when there is none.
    /// It is in the language of the device when the product has it in that language.
    public let storageText: String?

    public init(name: String, brands: String?, quantity: String?, categories: [String], storageText: String? = nil) {
        self.name = name
        self.brands = brands
        self.quantity = quantity
        self.categories = categories
        self.storageText = storageText
    }
}

/// Why a product lookup did not give an answer. The app keeps nothing for a failed lookup.
public enum LookupFailure: Hashable, Sendable, CaseIterable {
    /// The phone has no connection, or the server cannot be found.
    case noConnection
    /// The server did not answer in time.
    case timeout
    /// Too many lookups in a short time: the server refused, or the app stopped them (see `ProductLookup`).
    case busy
    /// The server gave an error, or an answer that the app cannot read.
    case server
}

/// The result of a product lookup.
public enum LookupResult: Hashable, Sendable {
    case found(LookedUpProduct)
    /// Open Food Facts has no product with a name for the barcode.
    case notFound
    case failed(LookupFailure)
}

/// An answer of the server: the HTTP status code and the bytes of the body.
public struct HttpResponse: Hashable, Sendable {
    public let status: Int
    public let body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }

    /// An answer with a body in UTF-8.
    public init(status: Int, text: String) {
        self.init(status: status, body: Data(text.utf8))
    }
}

/// Why a request got no answer. The transport of the app changes its errors into these values.
public enum HttpTransportError: Error, Hashable, Sendable {
    /// The server did not answer in time.
    case timeout
    /// No answer arrived for a different reason, for example no network, a server name that cannot be found, or a
    /// network that blocks the request.
    case noConnection
}

/// Sends a request to the internet. The product lookup is the only part of the app that uses it. The app implements
/// it with `URLSession`.
public protocol HttpTransport: Sendable {
    /// Sends a GET request and gives the answer. A cancellation of the task stops the request.
    ///
    /// - Throws: `HttpTransportError` when no answer arrives, and `CancellationError` when the task is cancelled. Each
    ///   other error is a failure of the connection.
    func get(url: URL, headers: [String: String]) async throws -> HttpResponse
}

/// The client of the product API of Open Food Facts (API version 2). It sends the barcode and nothing else, asks only
/// for the fields that the app uses, and does not try again by itself. The request uses HTTPS. It writes nothing to a
/// log.
public struct OpenFoodFactsClient: Sendable {
    private static let base = "https://world.openfoodfacts.org/api/v2/product/"

    private let transport: any HttpTransport
    private let userAgent: String

    /// - Parameter userAgent: The name and the version of the app (see `userAgent(version:)`). Open Food Facts asks
    ///   each app to send them. It has no data about the person.
    public init(transport: any HttpTransport, userAgent: String) {
        self.transport = transport
        self.userAgent = userAgent
    }

    /// The User-Agent of the iOS app: `CVKEFridge-iOS/<version>`.
    public static func userAgent(version: String) -> String {
        "CVKEFridge-iOS/\(version)"
    }

    /// Looks up the product of the `barcode`. `language` is the language code of the device, for example "en". The
    /// name in that language comes first when the product has one. The barcode must have only ASCII digits.
    ///
    /// - Throws: `CancellationError` when the task is cancelled. Each other problem is a `LookupResult.failed`.
    public func lookUp(barcode: String, language: String) async throws(CancellationError) -> LookupResult {
        precondition(
            !barcode.isEmpty && barcode.unicodeScalars.allSatisfy { $0.value >= 0x30 && $0.value <= 0x39 },
            "A barcode has only digits"
        )
        let response: HttpResponse
        do {
            response = try await transport.get(
                url: Self.url(barcode: barcode, language: language),
                headers: ["User-Agent": userAgent, "Accept": "application/json"]
            )
        } catch let error as CancellationError {
            throw error
        } catch HttpTransportError.timeout {
            return .failed(.timeout)
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            return .failed(.noConnection)
        }
        switch response.status {
        case 200, 404:
            switch OpenFoodFactsJSON.decode(response.body, language: language) {
            case .product(let product):
                return .found(product)
            case .noProduct:
                return .notFound
            case .unreadable:
                // A 404 with a body that is not JSON is still a "not found".
                return response.status == 404 ? .notFound : .failed(.server)
            }
        case 429, 503:
            return .failed(.busy)
        default:
            return .failed(.server)
        }
    }

    /// The URL of the lookup. It has the barcode and the names of the fields, and no other data.
    public static func url(barcode: String, language: String) -> URL {
        let names = OpenFoodFactsJSON.nameFields(language: language)
        let storage = OpenFoodFactsJSON.storageTextFields(language: language)
        let fields = (names + ["brands", "quantity", "categories_tags"] + storage).joined(separator: ",")
        guard let url = URL(string: "\(base)\(barcode)?fields=\(fields)") else {
            preconditionFailure("The URL of a lookup is not valid")
        }
        return url
    }
}

/// Reads the answers of the product API of Open Food Facts. The Kotlin name is `OpenFoodFactsJson`.
public enum OpenFoodFactsJSON {
    /// What an answer contains.
    public enum Decoded: Hashable, Sendable {
        case product(LookedUpProduct)
        /// The answer says that there is no product for the barcode, or the product has no name.
        case noProduct
        /// The text is not an answer of the API.
        case unreadable
    }

    /// The fields with a name, in the order that the app uses them: the product name in the language of the device,
    /// the product name in the main language of the product, the product name in English, and then the same for the
    /// generic name.
    public static func nameFields(language: String) -> [String] {
        ["product_name", "generic_name"].flatMap { fields(of: $0, language: language) }
    }

    /// The fields with the storage text, in the order that the app uses them: the text in the language of the
    /// device, the text in the main language of the product, and the text in English.
    public static func storageTextFields(language: String) -> [String] {
        fields(of: "conservation_conditions", language: language)
    }

    /// The `field` in the language of the device, in the main language of the product, and in English.
    private static func fields(of field: String, language: String) -> [String] {
        let lower = language.lowercased()
        let isCode = (2...3).contains(lower.unicodeScalars.count)
            && lower.unicodeScalars.allSatisfy { $0.value >= 0x61 && $0.value <= 0x7A }
        var result: [String] = []
        for name in [isCode ? "\(field)_\(lower)" : nil, field, "\(field)_en"].compactMap({ $0 })
        where !result.contains(name) {
            result.append(name)
        }
        return result
    }

    /// Reads one answer. A product is there when `status` is 1 and the product has a name. `status` 0 means that
    /// Open Food Facts has no product for the barcode, or that the barcode is not valid.
    public static func decode(_ body: Data, language: String) -> Decoded {
        guard case .object(let root)? = try? JSONDecoder().decode(JSONValue.self, from: body) else {
            return .unreadable
        }
        guard case .integer(let status)? = root["status"] else {
            return .unreadable
        }
        if status == 0 {
            return .noProduct
        }
        guard status == 1, case .object(let product)? = root["product"] else {
            return .unreadable
        }
        guard let name = nameFields(language: language).lazy.compactMap({ text(product[$0]) }).first else {
            return .noProduct
        }
        var categories: [String] = []
        if case .array(let tags)? = product["categories_tags"] {
            categories = tags.compactMap(text)
        }
        let storageText = storageTextFields(language: language).lazy.compactMap({ text(product[$0]) }).first
        return .product(
            LookedUpProduct(
                name: name,
                brands: text(product["brands"]),
                quantity: text(product["quantity"]),
                categories: categories,
                storageText: storageText
            )
        )
    }

    /// Reads one answer from a text in UTF-8.
    public static func decode(_ text: String, language: String) -> Decoded {
        decode(Data(text.utf8), language: language)
    }

    /// The text of a field with no spaces at the ends, or nil when it is not text or is empty.
    private static func text(_ value: JSONValue?) -> String? {
        guard case .string(let content)? = value else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// A JSON value with the types of JSON. An integer and a number with a fraction are different, so that `"status": 1`
/// and `"status": true` are different values.
enum JSONValue: Decodable, Hashable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
}
