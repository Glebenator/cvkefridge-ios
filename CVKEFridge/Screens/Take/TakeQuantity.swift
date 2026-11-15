import CVKEFridgeFeatures
import SwiftUI

/// Records food as used or as thrown away, with a quantity that the person types. PLACEHOLDER: this file records
/// the quantity of the first batch with no question. The Home and My Fridge agent replaces the body. The signature
/// `takeQuantity(_:)` stays.
///
/// Contract:
/// - A screen keeps `@State var take: TakeRequest?` and adds `.takeQuantity($take)`. To start, it sets the request.
/// - With only one item left (`TakeRequest.withoutDialog`), the modifier records it with no dialog. With more, it
///   shows a small sheet for the quantity (`TakeSource.of`, `TakeSource.check`), with the quantity of the oldest
///   batch at the start.
/// - The modifier calls `model.perform(.take(…))` and sets the binding to nil. The message with "Undo" comes from
///   the model.
extension View {
    func takeQuantity(_ request: Binding<TakeRequest?>) -> some View {
        modifier(TakeQuantityModifier(request: request))
    }
}

private struct TakeQuantityModifier: ViewModifier {
    @Binding var request: TakeRequest?
    @Environment(FridgeModel.self) private var model

    func body(content: Content) -> some View {
        content.onChange(of: request) { _, new in
            guard let new, let inventory = model.content?.inventory else { return }
            request = nil
            if let action = new.withoutDialog(inventory) {
                model.perform(.take(action))
            } else if let source = TakeSource.of(inventory: inventory, request: new) {
                model.perform(.take(.init(productId: new.productId, batchIds: new.batchIds,
                                          quantity: source.firstQuantity, outcome: new.outcome)))
            }
        }
    }
}
