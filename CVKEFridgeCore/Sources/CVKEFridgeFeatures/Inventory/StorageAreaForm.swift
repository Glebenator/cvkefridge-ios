import Foundation

// The form of a storage area.
// The Android file `app/src/main/java/com/cvke/fridge/inventory/StorageAreaForm.kt` in cvkefridge-android has the same
// behaviour.

/// What the person typed and selected in the form of a storage area.
public struct StorageAreaForm: Hashable, Sendable {
    /// The storage area that the form edits, or nil for a new one.
    public var id: String?
    public var name: String
    public var kind: StorageKind
    /// True after the person selected "Save" one time. The form then shows the problem of the name.
    public var checked: Bool

    public init(id: String?, name: String, kind: StorageKind, checked: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.checked = checked
    }

    /// The form for a new storage area, or for the `area`. A new storage area starts as a pantry.
    public static func of(_ area: StorageArea?) -> StorageAreaForm {
        StorageAreaForm(id: area?.id, name: area?.name ?? "", kind: area?.kind ?? .pantry)
    }

    /// The problem of the name. Two storage areas cannot have the same name, because a tab shows only the name.
    public func nameError(areas: [StorageArea]) -> NameError? {
        let cleaned = Names.clean(name)
        if cleaned.isEmpty {
            return .empty
        }
        if cleaned.count > Names.maxAreaLength {
            return .tooLong
        }
        if areas.contains(where: { $0.id != id && Names.same($0.name, cleaned) }) {
            return .inUse
        }
        return nil
    }

    /// The action that saves the form, or nil when the name has a problem.
    public func action(areas: [StorageArea]) -> InventoryAction.SaveStorageArea? {
        if nameError(areas: areas) != nil {
            return nil
        }
        return InventoryAction.SaveStorageArea(id: id, name: Names.clean(name), kind: kind)
    }
}
