import CVKEFridgeFeatures
import Foundation
import Testing

/// The answers of Open Food Facts and the request of the client. The Android test `OpenFoodFactsTest` has the same
/// cases.
struct OpenFoodFactsTests {
    private func lookUp(
        _ transport: FakeTransport,
        barcode: String = "3017620422003",
        language: String = "en"
    ) async throws -> LookupResult {
        try await OpenFoodFactsClient(transport: transport, userAgent: "CVKEFridge-iOS/0.1.0")
            .lookUp(barcode: barcode, language: language)
    }

    private func answer(_ status: Int, _ text: String) -> FakeTransport {
        FakeTransport { HttpResponse(status: status, text: text) }
    }

    private func product(_ decoded: OpenFoodFactsJSON.Decoded) -> LookedUpProduct? {
        if case .product(let product) = decoded {
            return product
        }
        return nil
    }

    @Test func aFoundProductHasItsNameBrandsQuantityAndTags() async throws {
        let result = try await lookUp(answer(200, LookupFixtures.text("nutella.json")))
        let expected = LookedUpProduct(
            name: "Nutella",
            brands: "Ferrero, Nutella",
            quantity: "400 g e",
            categories: [
                "en:breakfasts", "en:spreads", "en:sweet-spreads", "fr:pates-a-tartiner", "en:hazelnut-spreads",
                "en:confectionary-based-spreads", "fr:Nutella",
            ]
        )
        #expect(result == .found(expected))
    }

    @Test func theStorageTextInTheLanguageOfTheDeviceComesFirst() throws {
        let body = #"{"status":1,"product":{"product_name":"Pizza","conservation_conditions":"  ","#
            + #""conservation_conditions_de":" Bei -18 °C lagern. ","conservation_conditions_en":"Store at -18°C."}}"#
        func storageText(_ text: String, _ language: String) -> String? {
            product(OpenFoodFactsJSON.decode(text, language: language))?.storageText
        }
        #expect(storageText(body, "de") == "Bei -18 °C lagern.")
        // No French text is in the answer, and the text in the main language is empty.
        #expect(storageText(body, "fr") == "Store at -18°C.")
        // A product with no storage text.
        let nutella = try LookupFixtures.text("nutella.json")
        #expect(product(OpenFoodFactsJSON.decode(nutella, language: "en")) != nil)
        #expect(storageText(nutella, "en") == nil)
    }

    @Test func theNameInTheLanguageOfTheDeviceComesFirst() throws {
        let cola = try LookupFixtures.text("coca-cola.json")
        #expect(product(OpenFoodFactsJSON.decode(cola, language: "en"))?.name == "Coca-Cola")
        // No Spanish field is in the answer, so the main name of the product comes first.
        #expect(product(OpenFoodFactsJSON.decode(cola, language: "es"))?.name == "Coca-Cola Original")
    }

    @Test func emptyFieldsAreSkippedAndUnknownFieldsHaveNoEffect() throws {
        let messy = try #require(product(OpenFoodFactsJSON.decode(LookupFixtures.text("messy.json"), language: "de")))
        // product_name is empty, so the English name is next. The decoder trims only the ends.
        #expect(messy.name == "GREEK  STYLE\tYOGURT")
        #expect(messy.quantity == "6 x 150 g")
        #expect(messy.brands == ",  BIO&amp;GUT  , Hofmolkerei")
    }

    @Test func noProductNoNameAndAnInvalidCodeAreNotFound() async throws {
        #expect(try await lookUp(answer(404, LookupFixtures.text("not-found.json"))) == .notFound)
        #expect(try await lookUp(answer(200, LookupFixtures.text("invalid-code.json"))) == .notFound)
        #expect(try await lookUp(answer(200, LookupFixtures.text("no-name.json"))) == .notFound)
        // A 404 with a page that is not JSON is also "not found".
        #expect(try await lookUp(answer(404, "<html>Not found</html>")) == .notFound)
    }

    @Test func anAnswerThatIsNotTheApiIsAServerFailure() async throws {
        let server = LookupResult.failed(.server)
        #expect(try await lookUp(answer(200, "<html>Maintenance</html>")) == server)
        #expect(try await lookUp(answer(200, #"{"status":"success"}"#)) == server)
        #expect(try await lookUp(answer(200, #"{"status":1}"#)) == server)
        #expect(try await lookUp(answer(200, String(LookupFixtures.text("nutella.json").prefix(80)))) == server)
        #expect(try await lookUp(answer(500, "")) == server)
        #expect(try await lookUp(answer(400, "")) == server)
        // iOS: a JSON true is not the status 1.
        #expect(try await lookUp(answer(200, #"{"status":true,"product":{"product_name":"Milk"}}"#)) == server)
    }

    @Test func tooManyRequestsIsBusy() async throws {
        #expect(try await lookUp(answer(429, "")) == .failed(.busy))
        #expect(try await lookUp(answer(503, "")) == .failed(.busy))
    }

    @Test func aTimeoutIsATimeoutAndEachOtherNetworkFailureIsNoConnection() async throws {
        #expect(try await lookUp(FakeTransport { throw HttpTransportError.timeout }) == .failed(.timeout))
        #expect(try await lookUp(FakeTransport { throw HttpTransportError.noConnection }) == .failed(.noConnection))
        #expect(try await lookUp(FakeTransport { throw URLError(.secureConnectionFailed) }) == .failed(.noConnection))
        #expect(try await lookUp(FakeTransport { throw CocoaError(.fileReadUnknown) }) == .failed(.noConnection))
    }

    // iOS: a cancelled task gives no result. Android stops the coroutine in the same way.
    @Test func aCancelledLookupGivesNoResult() async {
        await #expect(throws: CancellationError.self) {
            try await lookUp(FakeTransport { throw CancellationError() })
        }
    }

    @Test func theRequestHasTheBarcodeTheFieldsAndTheNameOfTheAppOnly() async throws {
        let transport = answer(200, try LookupFixtures.text("nutella.json"))
        _ = try await lookUp(transport, language: "de")
        let request = try #require(transport.requests.value.first)
        #expect(transport.requestCount == 1)
        #expect(
            request.url.absoluteString == "https://world.openfoodfacts.org/api/v2/product/3017620422003?fields="
                + "product_name_de,product_name,product_name_en,generic_name_de,generic_name,generic_name_en,"
                + "brands,quantity,categories_tags,"
                + "conservation_conditions_de,conservation_conditions,conservation_conditions_en"
        )
        #expect(request.headers == ["User-Agent": "CVKEFridge-iOS/0.1.0", "Accept": "application/json"])
    }

    @Test func theUserAgentOfTheIosAppHasItsVersion() {
        #expect(OpenFoodFactsClient.userAgent(version: "1.2.0") == "CVKEFridge-iOS/1.2.0")
    }

    @Test func aLanguageThatIsNotACodeAddsNoField() {
        #expect(
            OpenFoodFactsJSON.nameFields(language: "en")
                == ["product_name_en", "product_name", "generic_name_en", "generic_name"]
        )
        #expect(
            OpenFoodFactsJSON.nameFields(language: "")
                == ["product_name", "product_name_en", "generic_name", "generic_name_en"]
        )
        #expect(!OpenFoodFactsJSON.nameFields(language: "x,y").contains(where: { $0.contains(",") }))
    }
}
