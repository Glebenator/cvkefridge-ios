import CVKEFridgeFeatures
import SwiftUI

/// The small picture of a product: its photo, or the icon of its category when it has no photo, in the same rounded
/// square. The cards of each screen use it. The photo is decorative, because the name of the food is next to it.
///
/// PLACEHOLDER: this file loads the photo with the loader of the model and shows it in an `IconTile`. The Photos
/// agent can replace the body. The signature `ProductImage(productId:category:size:tone:)` stays.
///
/// ```swift
/// ProductImage(productId: row.productId, category: row.category)
/// ProductImage(productId: product.id, category: product.category, size: 72)     // The top of the Food screen
/// ProductImage(productId: batch.productId, category: batch.category, tone: .on(.expired))
/// ```
///
/// Contract:
/// - The photo is `model.photos[productId]`. A photo that is ready in memory shows in the first frame
///   (`model.cachedImage(of:pixelSize:)`). If not, the icon shows while `model.image(of:pixelSize:)` decodes the
///   photo off the main actor.
/// - The side grows with the text size as the side of an `IconTile` does.
struct ProductImage: View {
    private let productId: String
    private let category: CVKEFridgeCore.Category
    private let size: CGFloat
    private let tone: TileTone

    @Environment(FridgeModel.self) private var model
    @Environment(\.displayScale) private var displayScale
    @State private var loaded: UIImage?

    /// - Parameters:
    ///   - size: The side at the default text size, in points.
    ///   - tone: The colours of the tile with the icon.
    init(productId: String, category: CVKEFridgeCore.Category, size: CGFloat = 40, tone: TileTone = .standard) {
        self.productId = productId
        self.category = category
        self.size = size
        self.tone = tone
    }

    var body: some View {
        let photo = model.photos[productId]
        // The tile can be 1.4 times its size with large text.
        let pixelSize = Int((size * 1.4 * displayScale).rounded(.up))
        let image = photo.flatMap { model.cachedImage(of: $0, pixelSize: pixelSize) } ?? loaded
        IconTile(category.icon, tone: tone, photo: image.map { Image(uiImage: $0) }, size: size)
            .task(id: photo) {
                loaded = nil
                if let photo {
                    loaded = await model.image(of: photo, pixelSize: pixelSize)
                }
            }
    }
}
