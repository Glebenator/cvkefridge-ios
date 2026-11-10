import Foundation
import Testing
@testable import CVKEFridgeCore

/// Runs each case of `spec/vectors/use-first.json` (rule 5). The Android test `UseFirstVectorsTest` runs the same
/// file.
struct UseFirstVectorsTests {
    @Test func orderCases() throws {
        let file = try Vectors.load("use-first.json")
        for item in try Vectors.cases(file, "cases") {
            let batches = try item.objects("batches").map { try Vectors.batch($0) }
            let actual: [String: Any] = ["order": UseFirst.order(batches).map { $0.id }]
            try Vectors.check(actual, item.object("expect"), item.string("name"))
        }
    }
}
