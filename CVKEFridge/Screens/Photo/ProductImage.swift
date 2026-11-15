import CVKEFridgeFeatures
import SwiftUI

/// The small picture of a product: its photo, or the icon of its category when it has no photo, in the same rounded
/// square. The cards of each screen use it. The photo is decorative, because the name of the food is next to it.
///
/// ```swift
/// ProductImage(productId: row.productId, category: row.category)
/// ProductImage(productId: product.id, category: product.category, size: 72)     // The top of the Food screen
/// ProductImage(productId: batch.productId, category: batch.category, tone: .on(.expired))
/// ```
///
/// - The photo is `model.photos[productId]`. A photo that is ready in memory shows in the first frame
///   (`model.cachedImage(of:pixelSize:)`). If not, the icon shows while `model.image(of:pixelSize:)` decodes the
///   photo off the main actor, and then the photo fades in over the icon. With Reduce Motion on, it comes with no
///   fade.
/// - The picture is decoded for the side on the screen in pixels. When the row goes off the screen before the decode,
///   the decode does not start.
/// - When the photo changes, the earlier photo stays until the new photo is ready, and then the new one fades in. When
///   the product has no photo now, the photo fades out. A photo file that cannot be decoded shows the icon.
/// - The side is the side of an `IconTile`: it grows with the text size, to 1.4 times at most. The size does not
///   change when the photo comes, so the layout does not move.
struct ProductImage: View {
    private let productId: String
    private let category: CVKEFridgeCore.Category
    private let size: CGFloat
    private let tone: TileTone

    @Environment(FridgeModel.self) private var model
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    /// The last photo that this view decoded or showed, with its picture.
    @State private var loaded: Loaded?

    private struct Loaded: Equatable {
        let photo: ProductPhoto
        let image: UIImage
    }

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
        let pixelSize = Int((size * min(scale, 1.4) * displayScale).rounded(.up))
        let shown = shownImage(photo: photo, pixelSize: pixelSize)
        ZStack {
            IconTile(category.icon, tone: tone, size: size)
            if let shown {
                IconTile(category.icon, tone: tone, photo: Image(uiImage: shown.image), size: size)
                    .id(shown.photo)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.enter, value: shown?.photo)
        .modifier(Decorative(productId: productId, shown: shown?.photo))
        .task(id: Request(photo: photo, pixelSize: pixelSize)) {
            await load(photo, pixelSize: pixelSize)
        }
    }

    /// The photo of a decode: a new task for each photo and each size.
    private struct Request: Equatable {
        let photo: ProductPhoto?
        let pixelSize: Int
    }

    /// The picture to show now: the picture of the photo in memory, or the picture that this view loaded, or the
    /// earlier photo while the new one loads. Nil for no photo.
    private func shownImage(photo: ProductPhoto?, pixelSize: Int) -> Loaded? {
        guard let photo else {
            return nil
        }
        if let loaded, loaded.photo == photo {
            return loaded
        }
        if let image = model.cachedImage(of: photo, pixelSize: pixelSize) {
            return Loaded(photo: photo, image: image)
        }
        return loaded
    }

    private func load(_ photo: ProductPhoto?, pixelSize: Int) async {
        guard let photo else {
            loaded = nil
            return
        }
        if let image = model.cachedImage(of: photo, pixelSize: pixelSize) {
            // The picture showed in the first frame. Keep it with no animation.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                loaded = Loaded(photo: photo, image: image)
            }
            return
        }
        let image = await model.image(of: photo, pixelSize: pixelSize)
        if Task.isCancelled {
            return
        }
        // A photo file that cannot be decoded shows the icon, not the earlier photo.
        loaded = image.map { Loaded(photo: photo, image: $0) }
    }
}

/// Hides the picture from VoiceOver: it is decorative. With the built-in pictures of the UI tests
/// (`TestPictures`), the debug build shows it to the tests, with the identifier `product_image_<product>` and the name
/// of the photo file on the screen, or "icon", as its value.
private struct Decorative: ViewModifier {
    let productId: String
    let shown: ProductPhoto?

    func body(content: Content) -> some View {
        #if DEBUG
        if TestPictures.kind != nil {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isImage)
                .accessibilityIdentifier("product_image_\(productId)")
                .accessibilityValue(Text(verbatim: shown?.url.lastPathComponent ?? "icon"))
        } else {
            content.accessibilityHidden(true)
        }
        #else
        content.accessibilityHidden(true)
        #endif
    }
}
