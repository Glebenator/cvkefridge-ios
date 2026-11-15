import CVKEFridgeFeatures
import SwiftUI

// The words of the messages, of the problems of a field, and of the reasons of the core.

extension NoticeText {
    /// The words of the message.
    var text: String {
        switch self {
        case .message(let message):
            return Wording.text(message)
        case .changesNotRead(let count):
            return count == 1
                ? String(localized: "\(count) change in the inventory file can't be read. The other food is here.")
                : String(localized: "\(count) changes in the inventory file can't be read. The other food is here.")
        case .custom(let text, _):
            return text
        }
    }

    /// The kind of the message: its icon, its colour, and its haptic signal.
    var kind: NoticeKind {
        switch self {
        case .message(let message):
            return Wording.kind(of: message)
        case .changesNotRead:
            return .problem
        case .custom(_, let kind):
            return kind
        }
    }
}

extension NoticeAction {
    /// The name of the button of a message.
    var title: LocalizedStringKey {
        switch self {
        case .undo: "Undo"
        case .tryAgain: "Try again"
        }
    }

    /// The name of the button, for VoiceOver and for the Undo of the system.
    var label: String {
        switch self {
        case .undo: String(localized: "Undo")
        case .tryAgain: String(localized: "Try again")
        }
    }
}

extension Wording {
    /// The words of a message of the inventory rules.
    static func text(_ message: NoticeMessage) -> String {
        switch message {
        case .added(let name):
            return String(localized: "\(name) added", comment: "The value is the name of a food.")
        case .taken(let name, let quantity, let unit, let outcome):
            let amount = Wording.quantity(quantity, unit: unit)
            switch outcome {
            case .used:
                return String(localized: "\(amount) of \(name) used", comment: "For example: 1.5 l of Whole milk used.")
            case .thrownAway:
                return String(localized: "\(amount) of \(name) thrown away", comment: "For example: 200 g of Baby spinach thrown away.")
            }
        case .foodDeleted(let name), .storageAreaDeleted(let name):
            return String(localized: "\(name) deleted", comment: "The value is the name of a food or of a storage area.")
        case .batchDeleted(let name, let count):
            return count == 1
                ? String(localized: "\(count) batch of \(name) deleted")
                : String(localized: "\(count) batches of \(name) deleted")
        case .expiryMoved(let name, let date):
            return String(localized: "\(name) now expires on \(Wording.date(date))")
        case .saveFailed:
            return String(localized: "Couldn't save the change. The inventory file can't be written.")
        case .refused(let reason):
            return reason.message
        case .remindersOn:
            return String(localized: "Reminders are on")
        case .remindersInSettings:
            return String(localized: "You can turn on reminders in Settings at any time.")
        case .settingsNotSaved:
            return String(localized: "Couldn't save the setting. Try again.")
        case .photoRemoved:
            return String(localized: "Photo removed")
        case .photoChanged:
            return String(localized: "Photo changed")
        case .productEdited(let name):
            return String(localized: "\(name) saved", comment: "The value is the name of a food that the person edited.")
        case .batchEdited(let name):
            return String(localized: "Batch of \(name) saved", comment: "The value is the name of a food.")
        case .noteSaved(let name):
            return String(localized: "Note of \(name) saved", comment: "The value is the name of a food.")
        case .noteRemoved(let name):
            return String(localized: "Note of \(name) removed", comment: "The value is the name of a food.")
        case .photoFailed:
            return String(localized: "Couldn't add the photo. Select a different picture.")
        case .photoNotRemoved:
            return String(localized: "Couldn't remove the photo. Try again.")
        }
    }

    /// The kind of a message of the inventory rules. It is `noticeTone` of `ui/FridgeApp.kt` of the Android app. The
    /// messages of an edit, of a note, and of a changed photo are not in the Android app.
    static func kind(of message: NoticeMessage) -> NoticeKind {
        switch message {
        case .added, .taken, .expiryMoved, .remindersOn, .photoChanged, .productEdited, .batchEdited, .noteSaved:
            .done
        case .foodDeleted, .batchDeleted, .storageAreaDeleted, .photoRemoved, .noteRemoved:
            .deleted
        case .remindersInSettings:
            .information
        case .saveFailed, .refused, .settingsNotSaved, .photoFailed, .photoNotRemoved:
            .problem
        }
    }

    /// The text of a form whose write failed: the reason of the core, or what to do when the file could not be
    /// written. The form shows it above its buttons.
    static func saveFailed(_ reason: RejectionReason?) -> String {
        reason?.message
            ?? String(localized: "Couldn't save. The inventory file can't be written. Your entries are still here. Try again.")
    }

    /// The text in the place of the content when the change log cannot be read.
    static var loadFailed: LocalizedStringKey {
        "Couldn't load items. The inventory file can't be read."
    }
}

extension RejectionReason {
    /// Why the core does not accept a change, in words for the person. A screen checks most of these cases before
    /// the write. The person sees the text when the inventory changed after the screen made its check.
    var message: String {
        switch self {
        case .unknownProduct:
            String(localized: "This food is no longer in the inventory.")
        case .unknownStorageArea:
            String(localized: "This storage area is no longer there. Select a different one.")
        case .unknownBatch:
            String(localized: "This batch is no longer in the inventory.")
        case .unknownChange, .cannotUndo:
            String(localized: "This can't be undone.")
        case .fixedStorageArea:
            String(localized: "Fridge and Freezer are fixed. You can't change or delete them.")
        case .storageAreaInUse:
            String(localized: "This storage area has food in it. Move the food, or record it as used or thrown away, and then delete the storage area.")
        case .invalidQuantity:
            QuantityProblem.notPositive.message
        case .duplicateBatch:
            String(localized: "Couldn't add the batch. Try again.")
        case .batchEnded:
            String(localized: "This batch has no quantity left.")
        }
    }
}

extension QuantityProblem {
    /// The problem of a quantity field, in words. The example number has the decimal sign of the locale.
    var message: String {
        switch self {
        case .empty:
            String(localized: "Enter a quantity.")
        case .notANumber:
            String(localized: "Enter a number, for example \(QuantityText.format(1_500, locale: .current)).")
        case .tooManyDecimals:
            String(localized: "Use 3 decimal places or fewer.")
        case .notPositive:
            String(localized: "Enter a quantity above 0.")
        case .tooLarge:
            String(localized: "The quantity is too large.")
        }
    }
}

extension NameError {
    /// The problem of the name of a food, in words.
    var foodMessage: String {
        switch self {
        case .empty: String(localized: "Enter a name.")
        case .tooLong: String(localized: "The name is too long. Use \(Names.maxFoodLength) characters or fewer.")
        case .inUse: String(localized: "Another food has this name.")
        }
    }

    /// The problem of the name of a storage area, in words.
    var areaMessage: String {
        switch self {
        case .empty: String(localized: "Enter a name.")
        case .tooLong: String(localized: "The name is too long. Use \(Names.maxAreaLength) characters or fewer.")
        case .inUse: String(localized: "Another storage area has this name.")
        }
    }
}
