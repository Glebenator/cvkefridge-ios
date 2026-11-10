import Foundation
import Testing
@testable import CVKEFridgeCore

/// Runs each case of `spec/vectors/plan-use.json` (rule 6). The Android test `PlanUseVectorsTest` runs the same file.
struct PlanUseVectorsTests {
    @Test func planCases() throws {
        let file = try Vectors.load("plan-use.json")
        for item in try Vectors.cases(file, "cases") {
            let batches = try item.objects("batches").map { try Vectors.batch($0) }
            let productId = try item.string("productId")
            let quantity = try item.int("quantity")
            let plan = UseFirst.plan(batches, productId: productId, quantity: quantity)
            var takes: [[String: Any]] = []
            for take in plan.takes {
                takes.append(["batchId": take.batchId, "quantity": take.quantity])
            }
            let actual: [String: Any] = ["takes": takes, "shortfall": plan.shortfall]
            try Vectors.check(actual, item.object("expect"), item.string("name"))
        }
    }
}
