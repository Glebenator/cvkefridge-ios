import CVKEFridgeFeatures
import SwiftUI

/// The note of a product on the screen of the food. A product with a note shows it on a card, and a tap on the card
/// edits it. A product with no note has "Add a note". It takes the place of `ui/FoodNote.kt` of the Android app.
struct FoodNoteRow: View {
    let note: String?
    /// Opens the editor of the note.
    let onEdit: () -> Void

    var body: some View {
        if let note {
            Button(action: onEdit) {
                SurfaceCard(.low) {
                    VStack(alignment: .leading, spacing: Space.s1) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Note")
                                .font(Typography.label)
                                .foregroundStyle(Palette.onSurfaceVariant)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(icon: .edit)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.onSurfaceVariant)
                                .accessibilityHidden(true)
                        }
                        Text(verbatim: note)
                            .font(Typography.body)
                            .foregroundStyle(Palette.onSurface)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .buttonStyle(.card)
            .accessibilityHint(Text("Edit the note"))
            .accessibilityIdentifier("food_note")
        } else {
            Button(action: onEdit) {
                Label("Add a note", icon: .addByHand)
            }
            .buttonStyle(.quiet)
            .accessibilityIdentifier("food_add_note")
        }
    }
}

/// The editor of the note of a product, in a small sheet. "Save" is above the keyboard, and the keyboard is open at
/// the start. A note with only spaces is removed (`Notes.clean`). The model gives the message "Note of … saved" or
/// "Note of … removed" with "Undo".
///
/// The Android app edits the note in the list of the screen, where the keyboard can cover "Save" and "Cancel". It has
/// no "Undo" for a note, and "Cancel" drops a changed note with no question. Here the close button asks first when the
/// person changed the text.
struct FoodNoteSheet: View {
    let productId: String
    /// Closes the sheet.
    let onClose: () -> Void

    @Environment(FridgeModel.self) private var model
    @State private var draft: String
    @FocusState private var focused: Bool

    /// The note at the start of the editor.
    private let start: String?

    /// - Parameter note: The note of the product now, or nil.
    init(productId: String, note: String?, onClose: @escaping () -> Void) {
        self.productId = productId
        self.onClose = onClose
        start = note
        _draft = State(initialValue: note ?? "")
    }

    var body: some View {
        FormSheet("Note", identifier: "food_note_screen", hasChanges: Notes.clean(draft) != start, onClose: onClose) {
            Section {
                TextField("Note", text: $draft, prompt: Text("For example: opened on Sunday"), axis: .vertical)
                    .lineLimit(3...8)
                    .focused($focused)
                    .accessibilityIdentifier("food_note_field")
            }
        } actions: {
            Button("Save", action: save)
                .buttonStyle(.floatingPrimary)
                .accessibilityIdentifier("food_note_save")
        }
        .onAppear { focused = true }
    }

    /// Saves the cleaned note when it is different from the note of the product, and closes the sheet. A write that
    /// fails gives the message with "Try again", so the text is not lost.
    private func save() {
        let note = Notes.clean(draft)
        if let product = model.content?.inventory.products.first(where: { $0.id == productId }), product.note != note {
            let changed = Product(
                id: product.id,
                name: product.name,
                category: product.category,
                unit: product.unit,
                barcode: product.barcode,
                foodId: product.foodId,
                note: note,
                storageText: product.storageText
            )
            model.perform(.saveProduct(.init(product: changed)))
        }
        onClose()
    }
}
