import CVKEFridgeFeatures
import Foundation

// The values that `FridgeModel` gives to the screens. The Android file `ui/FridgeViewModel.kt` has the same values:
// `FridgeUiState`, `Notice`, `FormWrite`, `LookupState`, `ShowRequest`, and `FormPhoto`.

/// What the screens show.
enum FridgeState: Equatable, Sendable {
    /// The first read of the change log is not complete.
    case loading
    /// The change log could not be read. `FridgeModel.load()` tries again.
    case failed
    /// The inventory.
    case ready(FridgeContent)
}

/// The inventory and all that the screens calculate from it, for one date. The model calculates it off the main
/// actor, one time for each change, so a screen only reads it.
struct FridgeContent: Equatable, Sendable {
    /// The replay of the change log. The forms and the screen of a food read it.
    let inventory: Inventory
    /// The change log of the `inventory`. "Add again" reads it for the newest batch of a product
    /// (`AddAgain.values(inventory:productId:changes:)`).
    let changes: [Change]
    /// What Home and My Fridge show: the totals, the batches that need attention, the storage areas, and the rows.
    let overview: InventoryContent
    /// What History shows, and the history of each product.
    let history: HistoryContent
    /// The date of the device. The days left are for this date.
    let today: CalendarDate
    /// The table of foods. It is empty for a short time after the start, while the app reads it, and when the app
    /// cannot read it.
    let foods: FoodTable
    /// False when the table of foods cannot be read. The inventory is there, but the forms have no expiry estimate
    /// and no suggestions from the table.
    let foodsAvailable: Bool
    /// The storage area of the last batch that this phone added and that is in the inventory, or nil. An add that
    /// the person undid does not count.
    let lastAreaId: String?
    /// The products that the person added, used, or threw away last, the newest first. `FridgeModel.shownRecent` has
    /// the list for the add form.
    let recent: [RecentFood]
    /// The number of lines of the change log that are not a change. The app did not read them. They stay in the file.
    let skippedChanges: Int
}

/// What a message says.
enum NoticeText: Hashable, Sendable {
    /// A message of the inventory rules.
    case message(NoticeMessage)
    /// Some lines of the change log are not a change, and the app did not read them. `count` is their number.
    case changesNotRead(count: Int)
    /// The add form saved the food with the `name`, but the food could not get the photo of the form. The message has
    /// "Try again".
    case photoNotAdded(name: String)
    /// A text that a screen made, already in the language of the person, with its kind.
    case custom(String, NoticeKind)
}

/// The button of a message.
enum NoticeAction: Hashable, Sendable {
    /// "Undo": takes back the action of the message.
    case undo
    /// "Try again": does the action of a failed write again.
    case tryAgain
}

/// A message for the person after an action. `NoticeHost` shows it as a floating card.
struct Notice: Identifiable, Equatable, Sendable {
    /// A number that is different for each message.
    let id: Int
    let text: NoticeText
    /// The button of the message, or nil. `FridgeModel.noticeAction(_:)` does its work.
    let action: NoticeAction?
}

/// The state of the write of one form. The model keeps one state for each form, by the token of the form, so a form
/// never reads the result of another form.
enum FormWrite: Equatable, Sendable {
    /// The write runs. The form shows that it saves, and its buttons are off.
    case saving
    /// The changes of the form are in the change log. The form closes, or starts the next entry.
    case saved
    /// Nothing was written. The value is the reason of the core, or nil when the file could not be written. The form
    /// stays as it is and says what failed.
    case failed(RejectionReason?)
}

/// The state of the product lookup of the scanner.
enum LookupState: Equatable, Sendable {
    case idle
    case looking(barcode: String)
    /// The add form can open with the values of the scan. The scanner opens it and then calls
    /// `FridgeModel.lookupShown(_:)` with the `id`. `productId` is the product in the inventory with the barcode, or
    /// nil.
    case done(id: Int, scanned: Scanned, productId: String?)
    /// The lookup failed. The scanner keeps the barcode for "Try again" and "Enter by hand".
    case failed(barcode: String, failure: LookupFailure)
}

/// A request to show My Fridge with a freshness filter, from a tap on the reminder. `RootView` shows it and then calls
/// `FridgeModel.showRequestDone(_:)` with the `id`.
struct ShowRequest: Equatable, Sendable {
    let id: Int
    let freshness: Set<Freshness>
}

/// The photo of an add form while the picture loads and the app makes the photo from it, and after.
enum FormPhoto: Equatable, Sendable {
    /// The picture loads, or the app makes the photo now. "Save" is off until it is ready.
    case making
    /// The photo is ready. `url` is its file, to show it, or nil when the file is not there.
    case ready(PreparedPhoto, url: URL?)
}

/// A picture that loads for an add form (`FridgeModel.startFormPhoto(token:)`). Only the newest load of the form can
/// give the form its photo.
struct FormPhotoLoad: Equatable, Sendable {
    let generation: Int
}

/// The reminder settings as the model knows them.
enum ReminderState: Equatable, Sendable {
    /// The first read is not complete.
    case loading
    /// The file of the settings cannot be read. The app changes nothing: the reminders that are planned stay. The
    /// next change of a setting by the person writes a new file.
    case unreadable
    case ready(ReminderSettings)

    /// The settings, or nil when they are not read.
    var settings: ReminderSettings? {
        if case .ready(let settings) = self {
            return settings
        }
        return nil
    }
}
