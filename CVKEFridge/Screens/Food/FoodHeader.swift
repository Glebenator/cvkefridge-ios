import CVKEFridgeFeatures
import SwiftUI

/// The top of the screen of a food: the product with its photo.
///
/// - A product with a photo shows the photo at the top, then "Change photo" and "Remove photo", then the name.
/// - A product with no photo shows the icon of its category next to the name, then "Take a photo" and "Choose a
///   photo".
/// - While the app makes the photo from a picture, the photo controls say "Adding the photo…".
///
/// It takes the place of `ProductHeader` and `FoodPhoto` of `ui/FoodDetailScreen.kt` of the Android app.
struct FoodHeader: View {
    let detail: FoodDetail
    /// The height of the visible part of the screen, or 0 when it is not known. It limits the height of the photo.
    let viewportHeight: CGFloat
    /// Gives the bottom edge of the name, in the coordinate space `FoodScreen.contentSpace`. The navigation bar
    /// shows the name when the name is above the visible part.
    let onNameBottom: (CGFloat) -> Void

    @Environment(FridgeModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let product = detail.product
        let photo = model.photos[product.id]
        VStack(alignment: .leading, spacing: Space.s2) {
            if let photo {
                FoodPhoto(photo: photo, name: product.name, maxHeight: maxPhotoHeight)
                    .transition(.rise)
            } else {
                // With large text, the name gets all of the width, below the icon.
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s3))
                    : AnyLayout(HStackLayout(spacing: Space.s4))
                layout {
                    IconTile(product.category.icon, size: 56)
                    names
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // The controls stay at one place in the view tree, with and with no photo. Thus a picker or a camera
            // that they show stays open while the photo of the product changes.
            FlowLayout(spacing: Space.s2) {
                PhotoSourceButtons(
                    hasPhoto: photo != nil,
                    isBusy: model.photoImports.contains(product.id),
                    onPicture: { model.setPhoto(productId: product.id, picture: $0) },
                    onRemove: { model.removePhoto(productId: product.id) }
                )
            }
            .buttonStyle(.quiet)
            if photo != nil {
                names
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Space.s1)
            }
        }
        .motion(Motion.enter, value: photo)
    }

    /// The name of the product in full, and its category with the sum of its batches.
    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: detail.product.name)
                .font(Typography.sectionTitle)
                .foregroundStyle(Palette.onSurface)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("food_name")
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .named(FoodScreen.contentSpace)).maxY
                } action: { bottom in
                    onNameBottom(bottom)
                }
            Text(verbatim: FoodWords.summary(of: detail))
                .font(Typography.body)
                .foregroundStyle(Palette.onSurfaceVariant)
                .contentTransition(.numericText())
                .accessibilityLabel(Text(verbatim: FoodWords.spoken(FoodWords.summary(of: detail))))
                .accessibilityIdentifier("food_summary")
        }
    }

    /// The photo is not higher than 280 points or 40% of the visible part of the screen. On a phone on its side, the
    /// photo then leaves space for the name and the batches.
    private var maxPhotoHeight: CGFloat {
        viewportHeight > 0 ? min(280, viewportHeight * 0.4) : 280
    }
}

/// The photo of a product as a large picture with round corners, cropped to a box as wide as the content and three
/// quarters as high, but not higher than `maxHeight`. The picture is decoded off the main actor. Until it is ready,
/// the box has a quiet fill.
private struct FoodPhoto: View {
    let photo: ProductPhoto
    let name: String
    let maxHeight: CGFloat

    @Environment(FridgeModel.self) private var model
    @State private var loaded: UIImage?

    var body: some View {
        // The file of a photo is not larger than `PhotoFiles.maxEdge`, so the screen uses the full picture.
        let image = model.cachedImage(of: photo, pixelSize: PhotoFiles.maxEdge) ?? loaded
        PhotoBox(maxHeight: maxHeight) {
            Palette.surfaceContainerHigh
                .overlay {
                    if let image {
                        // The picture is larger than the box in one direction. The box cuts it, and the box is the
                        // element of VoiceOver.
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .transition(.fade)
                    }
                }
                .clipShape(Radius.shape(Radius.large))
        }
        .motion(Motion.enter, value: image != nil)
        .task(id: photo) {
            loaded = nil
            loaded = await model.image(of: photo, pixelSize: PhotoFiles.maxEdge)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Photo of \(name)", comment: "VoiceOver reads it for the photo of a food. The value is the name of the food."))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("food_photo")
        .modifier(PhotoFileValue(photo: photo))
    }
}

/// With the built-in pictures of the UI tests (`TestPictures`), the debug build gives the name of the photo file as
/// the value of the photo. A test then knows which photo shows, as for the small picture of a card (`ProductImage`).
private struct PhotoFileValue: ViewModifier {
    let photo: ProductPhoto

    func body(content: Content) -> some View {
        #if DEBUG
        if TestPictures.kind != nil {
            content.accessibilityValue(Text(verbatim: photo.url.lastPathComponent))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// A box as wide as the width that it gets, and three quarters as high, but not higher than `maxHeight`.
private struct PhotoBox: Layout {
    let maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        return CGSize(width: width, height: min(width * 0.75, maxHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
