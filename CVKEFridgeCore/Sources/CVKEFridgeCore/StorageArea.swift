import Foundation

// A storage area and its kind. Rules 1 and 7 of `spec/rules.md`.
// The Android file `core/src/main/kotlin/com/cvke/fridge/core/StorageArea.kt` in cvkefridge-android has the same
// types.

/// The kind of a storage area.
public enum StorageKind: String, CaseIterable, Sendable {
    case pantry
    case fridge
    case freezer
}

/// A place where batches are kept. Each storage area has one kind. A fixed storage area cannot be changed or deleted.
public struct StorageArea: Hashable, Sendable {
    public let id: String
    public let name: String
    public let kind: StorageKind
    public let fixed: Bool

    public init(id: String, name: String, kind: StorageKind, fixed: Bool) {
        self.id = id
        self.name = name
        self.kind = kind
        self.fixed = fixed
    }

    /// The fixed storage area `fridge`.
    public static let fridge = StorageArea(id: "fridge", name: "Fridge", kind: .fridge, fixed: true)

    /// The fixed storage area `freezer`.
    public static let freezer = StorageArea(id: "freezer", name: "Freezer", kind: .freezer, fixed: true)
}
