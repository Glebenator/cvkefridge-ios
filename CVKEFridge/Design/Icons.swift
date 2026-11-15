import CVKEFridgeCore
import SwiftUI

/// The icons of the app. Each is an SF Symbol, so it follows the text size and the text weight.
///
/// Each case has the symbol for the drawable of the same use in the Android app (`res/drawable/ic_*.xml`). Use a case,
/// not a symbol name, so that one thing has one icon on each screen.
///
/// ```swift
/// Image(icon: .scan)
/// Label("Thrown away", icon: .delete)
/// Image(icon: .home, filled: isSelected)
/// ```
///
/// SF Symbols has no cheese, no steak, and no bread. Dairy is a drop, meat is a fish, and bakery is a cake.
enum AppIcon: CaseIterable, Sendable {
    // The tabs. Android: ic_home, ic_fridge, ic_history, ic_settings.
    case home
    case fridge
    case history
    case settings

    // Actions.
    /// ic_add
    case add
    /// ic_pencil_plus: "Add by hand", "Add a note".
    case addByHand
    /// ic_barcode_scan
    case scan
    /// ic_edit
    case edit
    /// ic_trash: "Thrown away", and "Delete".
    case delete
    /// ic_check: "Used", and a selected item of a menu or a chip.
    case check
    /// ic_close
    case close
    /// ic_arrow_back. A navigation bar has its own back button. Use this only out of a bar.
    case back
    /// ic_chevron_right: a tap opens something.
    case forward
    /// ic_menu_down: a tap opens a menu.
    case menuDown
    /// ic_more
    case more
    /// ic_search
    case search
    /// ic_sort
    case sort
    /// ic_arrow_up: ascending order.
    case ascending
    /// ic_arrow_down: descending order.
    case descending
    /// The button of a message that takes back an action.
    case undo

    // Values.
    /// ic_calendar: a date.
    case calendar
    /// ic_clock: a time, and the status "expiring".
    case clock
    /// ic_keyboard: type a value.
    case keyboard
    /// ic_info: information, and About.
    case info
    /// ic_check_circle: an action is done, and "all fresh".
    case done
    /// ic_alert and ic_alert_outline: a problem, and the status "expired".
    case alert

    // The reminder.
    /// ic_bell
    case bell
    /// ic_bell_off
    case bellOff
    /// ic_stat_reminder
    case reminder

    // The camera and the photo.
    /// ic_camera
    case camera
    /// ic_camera_off: no camera, or no camera access.
    case cameraOff
    /// ic_flashlight: the light is off, and a tap turns it on.
    case flashlightOn
    /// ic_flashlight_off: the light is on, and a tap turns it off.
    case flashlightOff
    /// ic_image_plus: "Choose a photo".
    case photoAdd
    /// ic_image_edit: "Change photo".
    case photoChange
    /// ic_image_remove: "Remove photo".
    case photoRemove

    // The product lookup.
    /// ic_wifi_off: no connection.
    case offline
    /// ic_cloud_off: the service did not answer.
    case serviceUnavailable

    // The categories. Android: `Category.icon()` in `ui/DisplayFormat.kt`.
    /// ic_carrot
    case produce
    /// ic_cheese
    case dairy
    /// ic_food_steak
    case meat
    /// ic_bottle_soda
    case condiment
    /// ic_cup
    case beverage
    /// ic_bread_slice
    case bakery
    /// ic_food_variant
    case leftovers
    /// ic_food_variant
    case otherFood

    // The kinds of storage area. The Android app has no icons for them.
    case freezer
    case pantry

    /// The name of the SF Symbol in its usual form. Tiles, lists, and buttons use this form.
    var symbol: String {
        switch self {
        case .home: "house"
        case .fridge: "refrigerator"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        case .add: "plus"
        case .addByHand: "square.and.pencil"
        case .scan: "barcode.viewfinder"
        case .edit: "pencil"
        case .delete: "trash"
        case .check: "checkmark"
        case .close: "xmark"
        case .back: "chevron.backward"
        case .forward: "chevron.forward"
        case .menuDown: "chevron.down"
        case .more: "ellipsis"
        case .search: "magnifyingglass"
        case .sort: "arrow.up.arrow.down"
        case .ascending: "arrow.up"
        case .descending: "arrow.down"
        case .undo: "arrow.uturn.backward"
        case .calendar: "calendar"
        case .clock: "clock"
        case .keyboard: "keyboard"
        case .info: "info.circle"
        case .done: "checkmark.circle"
        case .alert: "exclamationmark.circle"
        case .bell: "bell"
        case .bellOff: "bell.slash"
        case .reminder: "bell.badge"
        case .camera: "camera"
        case .cameraOff: "video.slash"
        case .flashlightOn: "flashlight.on.fill"
        case .flashlightOff: "flashlight.slash"
        case .photoAdd: "photo.badge.plus"
        case .photoChange: "photo.on.rectangle.angled"
        case .photoRemove: "trash"
        case .offline: "wifi.slash"
        case .serviceUnavailable: "icloud.slash"
        case .produce: "carrot"
        case .dairy: "drop"
        case .meat: "fish"
        case .condiment: "waterbottle"
        case .beverage: "mug"
        case .bakery: "birthday.cake"
        case .leftovers: "takeoutbag.and.cup.and.straw"
        case .otherFood: "fork.knife"
        case .freezer: "snowflake"
        case .pantry: "cabinet"
        }
    }

    /// The name of the filled form of the symbol, or the usual form when the symbol has no filled form. A selected
    /// tab, an icon on a tile, and an icon of a status use the filled form.
    var filledSymbol: String {
        switch self {
        case .home, .fridge, .settings, .delete, .clock, .keyboard, .info, .done, .alert, .bell, .bellOff, .reminder,
             .camera, .cameraOff, .photoAdd, .photoChange, .photoRemove, .serviceUnavailable, .produce, .dairy, .meat,
             .condiment, .beverage, .bakery, .leftovers, .pantry:
            symbol + ".fill"
        case .history, .add, .addByHand, .scan, .edit, .check, .close, .back, .forward, .menuDown, .more, .search,
             .sort, .ascending, .descending, .undo, .calendar, .flashlightOn, .flashlightOff, .offline, .otherFood,
             .freezer:
            symbol
        }
    }

    /// The symbol name of the usual or of the filled form.
    func symbol(filled: Bool) -> String {
        filled ? filledSymbol : symbol
    }
}

extension Image {
    /// The image of an icon of the app.
    init(icon: AppIcon, filled: Bool = false) {
        self.init(systemName: icon.symbol(filled: filled))
    }
}

extension Label where Title == Text, Icon == Image {
    /// A label with an icon of the app. The title is a key of the string catalog.
    init(_ title: LocalizedStringKey, icon: AppIcon, filled: Bool = false) {
        self.init(title, systemImage: icon.symbol(filled: filled))
    }

    /// A label with an icon of the app. The title is text of the person or text that is already localized.
    init(verbatim title: String, icon: AppIcon, filled: Bool = false) {
        self.init { Text(verbatim: title) } icon: { Image(icon: icon, filled: filled) }
    }
}

extension CVKEFridgeCore.Category {
    /// The icon of the category. "Leftovers" has its own icon on iOS. On Android it has the icon of "Other".
    var icon: AppIcon {
        switch self {
        case .produce: .produce
        case .dairy: .dairy
        case .meat: .meat
        case .condiment: .condiment
        case .beverage: .beverage
        case .bakery: .bakery
        case .leftovers: .leftovers
        case .other: .otherFood
        }
    }
}

extension StorageKind {
    /// The icon of the kind of storage area.
    var icon: AppIcon {
        switch self {
        case .pantry: .pantry
        case .fridge: .fridge
        case .freezer: .freezer
        }
    }
}
