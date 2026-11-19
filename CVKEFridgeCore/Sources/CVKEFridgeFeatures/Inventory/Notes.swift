import Foundation

// The note of a product.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/Notes.kt` in cvkefridge-android has the same behaviour.

/// The note of a product, as the person typed it. The core keeps a note as it is, so the app cleans it first.
public enum Notes {
    /// The note to save: the text without spaces at the start and at the end, or nil for an empty text.
    public static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
