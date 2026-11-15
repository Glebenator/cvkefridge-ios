# Plan: the iOS app with the features of the Android app

Date: 14 November 2026. Reference: cvkefridge-android at commit `8ad4020`, cvkefridge at commit `c4e1d3f`.

## 1. Goal

The iOS app gets each feature of the Android app, with the same product rules and the same words. The screens have
the same contents and the same order as on Android, but each control is the native iOS control. A defect of the
Android app is not copied. Where iOS can do a thing better, the iOS app does it better, and section 6 records the
difference.

`CVKEFridgeCore` is already equal to `:core` of Android (the same `spec/` commit). This plan adds all that is above
the core.

## 2. Structure

```text
CVKEFridgeCore/                      One Swift package, two targets
  Sources/CVKEFridgeCore/            The product rules of spec/. Mirror of :core. No change in this plan.
  Sources/CVKEFridgeFeatures/        Foundation only. Port of the plain Kotlin of the Android app module:
    Inventory/                       inventory/*  (actions, forms, add again, suggestions, storage advice, ...)
    History/                         history/*
    Lookup/                          lookup/*     (barcodes, Open Food Facts, mapping, lookup, cache) + scan/ScanDebouncer
    Reminder/                        reminder/*   (rules, schedule, settings value, text values)
    Photo/                           photo/PhotoFiles and the file rules of PhotoStore
    Content/                         ui/InventoryContent, ui/FoodDetail, the pure parts of ui/DisplayFormat, settings/*
  Tests/CVKEFridgeFeaturesTests/     Port of app/src/test. The same cases as the Kotlin tests. `swift test` runs them.
CVKEFridge/
  App/                               App entry, AppEnvironment (the objects that live as long as the app)
  Model/                             FridgeModel (@Observable, @MainActor; port of FridgeViewModel), stores
  Platform/                          ChangeLogStore, PhoneId, JSON settings stores, HTTP transport, camera, photos, notifications
  Design/                            Theme (colours), Brand (gradient, slice, spinner), Motion, Haptics, components
  Shell/                             RootView (tabs), Route, sheets, NoticeHost
  Screens/Home, MyFridge, Food, Add, Edit, History, Scan, Settings, StorageAreas
CVKEFridgeUITests/                   Port of the Android device tests, on the real app with launch arguments
```

Rules:

- A Swift file that ports a Kotlin file has the same name (`AddFoodForm.kt` becomes `AddFoodForm.swift`), the same
  behaviour, and the same test cases.
- `CVKEFridgeFeatures` has no UIKit, no SwiftUI, and no localized text. A rule that makes text gives a value, and the
  app makes the words.
- One `FridgeModel` owns the inventory state. Views read it and send actions. Dependencies go through initializers.
- Swift 6 language mode with complete concurrency checks. Disk and network work are in actors, off the main actor.
- No third-party dependency.

## 3. Android to iOS

| Android | iOS |
|---|---|
| Material 3 scheme from `#53D181`; wallpaper colours | One fixed scheme from `#53D181`, light and dark (`Design/Theme.swift`). No wallpaper setting. |
| Navigation bar with a raised add button | `TabView` with the iOS 26 Liquid Glass tab bar: Home, My Fridge, History, Settings. Add is one separate glass button at the bar. |
| Screens above the tabs | Food and Storage areas are pushed in a `NavigationStack`. Add, Scan, Edit, and pickers are sheets. |
| Top app bar actions and overflow menus | Toolbar items and `Menu`. Glass comes from the system bars; content has no custom glass. |
| Card with a three-dot menu, swipe for used and thrown away | `swipeActions` (leading: Used, trailing: Thrown away), a context menu, and the same actions as VoiceOver custom actions. |
| Tabs of the storage areas, chips, sort | A scrolling segmented row of glass capsules, filter chips, a sort `Menu`, `.searchable`. |
| Snackbar card (`NoticeHost`) | A glass capsule above the tab bar with Undo or Try again, a haptic, and a VoiceOver announcement. |
| Material date and time pickers | `DatePicker` (graphical in a sheet; hour and minute). |
| CameraX and ML Kit | `AVCaptureSession` with `AVCaptureMetadataOutput` (EAN-13, EAN-8, UPC-A, UPC-E). No library. |
| `HttpsURLConnection` | `URLSession` (ephemeral, 10 s timeouts), User-Agent `CVKEFridge-iOS/<version>`. |
| Photo picker, camera app, `ImageDecoder`, `LruCache` | `PhotosPicker`, the system camera, ImageIO downsampling to 1024 px, JPEG with no metadata, `NSCache`. |
| `AlarmManager` and a receiver that reads the log at the time | Local notifications with calendar triggers. The app plans the reminder of each of the next days from the expiry dates, and plans again after each change, each start, and each change of the clock. |
| DataStore JSON files | Small JSON files in Application Support, written atomically, not in the backup. |
| Vibration | `sensoryFeedback` and UIKit feedback generators: selection, success, warning, error. |
| Debug sample with an intent extra | Debug build only: launch argument `-inventory sample` or `-inventory empty`. |

Access, on each screen: Dynamic Type to the largest size, VoiceOver labels and actions, targets of 44 points,
Reduce Motion, Reduce Transparency, Increase Contrast, light and dark, rotation, and iPad width.

## 4. Order of work

| Wave | Work | Agents |
|---|---|---|
| 0 | This plan, the package target, the branch `android-parity` | Orchestrator |
| 1 | In parallel: (A) Inventory, History, Content rules. (B) Lookup, Reminder, Photo rules. (C) Design system. | Opus, Opus, Fable |
| 2 | The shell: model, stores, navigation, tabs, notices, shared form parts, sample, UI test harness, stub screens | Fable |
| 3 | In parallel: Home and My Fridge and Storage areas; Add form and Edit forms; Food screen; History; Scanner and lookup; Reminders and Settings; Photos | Fable and Opus |
| 4 | Integration: string catalog, access review, UI tests, CI, README, review of the whole diff | Fable, Opus |

Each agent of a parallel wave works in its own Git worktree and owns a fixed set of files. The orchestrator merges
the branches and makes the build and the tests pass before the next wave.

## 5. Checks

- `swift test` in `CVKEFridgeCore`: the vectors and the ported Kotlin tests.
- `xcodebuild build-for-testing`, with no warning from the app code.
- UI tests on a simulator, in light and in dark appearance, and one run with the largest text size.
- Screenshots of each screen from the simulator, compared with the Android screenshots in
  `cvkefridge/docs/progress/images`.
- A real iPhone is necessary for the camera, the scanner, haptics, and the time of a reminder.

## 6. Intended differences from Android

Each of these needs an ADR in the cvkefridge repository before the work is complete.

1. No "Wallpaper colours": iOS has no wallpaper colour scheme.
2. Four tabs and a separate add button, sheets for forms, and swipe actions and context menus for card actions.
3. The reminder is planned ahead as local notifications. It does not read the change log at the time of the reminder.
4. The scanner uses the barcode reader of AVFoundation, not ML Kit.
5. Corrections of Android defects that the review found. The list is in section 7.

## 7. Android defects that the iOS app does not copy

The review of the Android app fills this section.
