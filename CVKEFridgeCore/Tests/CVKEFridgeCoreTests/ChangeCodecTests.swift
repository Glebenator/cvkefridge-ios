import Foundation
import Testing
@testable import CVKEFridgeCore

/// Tests `ChangeCodec` with the changes in `spec/vectors/change-log.json` and with input that is not valid.
/// The Android test `ChangeCodecTest` has the same cases.
struct ChangeCodecTests {
    @Test func everyVectorChangeHasTheSameValueAfterEncodeAndDecode() throws {
        let file = try Vectors.load("change-log.json")
        var count = 0
        for item in try Vectors.cases(file, "cases") {
            let name = try item.string("name")
            for change in try item.objects("changes") {
                let text = try Vectors.canonical(change)
                let decoded = try ChangeCodec.decode(text)
                let encoded = ChangeCodec.encode(decoded)
                let again = try ChangeCodec.decode(encoded)
                #expect(again == decoded, "\(name): \(text)")
                // The encoded text has the JSON shape of the vector file, with each null.
                let shape = try Vectors.canonical(JSONSerialization.jsonObject(with: Data(encoded.utf8)))
                #expect(shape == text, "\(name): \(text)")
                count += 1
            }
        }
        #expect(count > 0, "change-log.json has changes")
    }

    @Test func invalidInputThrows() {
        let invalid: [String] = [
            "",
            "[]",
            "not JSON",
            // An unknown type.
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"productRenamed","productId":"p-1"}}"#,
            // A date that is not valid.
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"batchUsed","batchId":"b-1","quantity":500,"date":"2026-02-30"}}"#,
            // Unknown enum texts.
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"storageAreaSaved","area":{"id":"s-1","name":"Shelf","kind":"cellar"}}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"productSaved","product":{"id":"p-1","name":"Eggs","category":"dairy","unit":"dozen","barcode":null,"foodId":null}}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"productSaved","product":{"id":"p-1","name":"Eggs","category":"fish","unit":null,"barcode":null,"foodId":null}}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"batchAdded","batch":{"id":"b-1","productId":"p-1","quantity":1000,"storageAreaId":"fridge","dateAdded":"2026-11-10","expiryDate":"2026-11-12","expirySource":"guessed"}}}"#,
            // Only one of the two expiry values.
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"batchEdited","batchId":"b-1","quantity":500,"storageAreaId":"fridge","dateAdded":"2026-11-10","expiryDate":"2026-11-12","expirySource":null}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"batchAdded","batch":{"id":"b-1","productId":"p-1","quantity":1000,"storageAreaId":"fridge","dateAdded":"2026-11-10","expiryDate":null,"expirySource":"printed"}}}"#,
            // Wrong JSON types.
            #"{"id":"c-1","at":"1","origin":"phone-a","body":{"type":"changeUndone","changeId":"c-0"}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"batchUsed","batchId":"b-1","quantity":"500","date":"2026-11-10"}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"productDeleted","productId":5}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"productSaved","product":{"id":"p-1","name":"Jam","category":"condiment","unit":null,"barcode":null,"foodId":null,"note":5}}}"#,
            // Missing keys.
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"batchDeleted"}}"#,
            #"{"id":"c-1","at":1,"body":{"type":"batchDeleted","batchId":"b-1"}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"productSaved","product":{"id":"p-1","name":"Eggs","category":"dairy","unit":null,"barcode":null}}}"#,
            #"{"id":"c-1","at":1,"origin":"phone-a","body":{"type":"batchEdited","batchId":"b-1","quantity":500,"storageAreaId":"fridge","dateAdded":"2026-11-10"}}"#,
        ]
        for text in invalid {
            var threw = false
            do {
                _ = try ChangeCodec.decode(text)
            } catch {
                threw = true
            }
            #expect(threw, "decode must throw for \(text)")
        }
    }
}
