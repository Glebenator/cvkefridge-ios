# CVKE Fridge for iOS

[![iOS CI](https://github.com/Glebenator/cvkefridge-ios/actions/workflows/ios.yml/badge.svg?branch=main)](https://github.com/Glebenator/cvkefridge-ios/actions/workflows/ios.yml?query=branch%3Amain)

A native iOS app for the food inventory of a fridge. It has the features of the Android app, with the same product
rules and the same words, and each control is the native iOS control. Built with SwiftUI and the iOS 26 design.

CVKE Fridge has three repositories:

| Repository | Contents |
|---|---|
| [cvkefridge](https://github.com/Glebenator/cvkefridge) | The product: plan, glossary, and decisions |
| [cvkefridge-android](https://github.com/Glebenator/cvkefridge-android) | The Android app |
| **cvkefridge-ios** | This repository: the iOS app, with the same product rules as Android |

## Status

- **Development build.** The app is not published. The bundle ID `com.example.cvkefridge` is a development ID.
- **Scope.** Home, My Fridge, the screen of a food, the add form, the edit forms, History, the barcode scanner
  with the product lookup, photos, the daily reminder, storage areas, and Settings.
  [docs/android-parity-plan.md](docs/android-parity-plan.md) has the structure, the differences from Android, and
  the Android defects that this app does not copy.
- **Core rules.** The `CVKEFridgeCore` package has two targets. `CVKEFridgeCore` has the product rules of
  `spec/rules.md`. `CVKEFridgeFeatures` has the rules of the forms, History, the lookup, the reminder, and the photo
  files. The two use Foundation only.
- **Network.** The app connects only to `world.openfoodfacts.org`, for the product lookup of a barcode.
- **Not checked on a real iPhone yet.** The camera and the scanner, a photo from the camera, haptics, the time of a
  reminder, VoiceOver, battery use, and speed.
- **CI.** The badge above shows the result of the newest run on `main`. Select it to see all runs.

### What CI checks

The workflow [`ios.yml`](.github/workflows/ios.yml) runs for each push to `main` and each pull request, on a
`macos-26` runner.

| Check | How | In CI |
|---|---|---|
| Copy of the shared specification | `python3 scripts/update-spec.py --check` | Yes |
| Product rules | `swift test` in `CVKEFridgeCore`, with each case in `spec/vectors/` | Yes |
| Rules of the features | `swift test` in `CVKEFridgeCore`, the ported tests of the Android app | Yes |
| App and test build | `xcodebuild build-for-testing`, without signing, in each `app` job | Yes |
| Unit tests of the app | `CVKEFridgeTests`, in the job `app (light)` | Yes |
| All UI tests in light mode | `CVKEFridgeUITests`, in the job `app (light)` | Yes |
| All UI tests in dark mode | `CVKEFridgeUITests`, in the job `app (dark)` | Yes |
| Largest text size | `CVKEFridgeUITests`, on a Mac | No |
| Real iPhone checks | Manual | No |

The jobs `core`, `app (light)`, and `app (dark)` run at the same time. The workflow installs XcodeGen at the version
in `XCODEGEN_VERSION`. Each `app` job uploads the screenshots of its UI tests as the `ios-captures-light` or the
`ios-captures-dark` artifact.

## Build and run

1. Use a Mac with Xcode 26 or later. The app needs iOS 26.0 or later.
2. Install XcodeGen: `brew install xcodegen`.
3. In this folder, run `xcodegen generate`. It makes `CVKEFridge.xcodeproj`, which is not in Git.
4. Open `CVKEFridge.xcodeproj`. Select the `CVKEFridge` scheme and an iPhone simulator or a phone.
5. For a phone, select your team in Signing & Capabilities for the `CVKEFridge` target. A personal team can need
   another bundle ID than the development ID `com.example.cvkefridge`.
6. Run.

The app needs no API key.

## Tests

- **Core tests.** In `CVKEFridgeCore`, run `swift test`. The tests read the vector files in `spec/vectors/` and run
  each case through the core. They compare the complete expected result. A missing file, or a section with no cases,
  makes a test fail. The Android core tests use the same vector files. The core uses Foundation only, so that the
  tests can also run on Linux with the Swift toolchain.
- **Feature tests.** The same command runs the tests of `CVKEFridgeFeatures`. They have the same cases as the
  tests of the Android app module.
- **Unit tests of the app.** `CVKEFridgeTests` tests the model, the change log file, the photo encoder, the reminder
  triggers, and the scanner rules.
- **UI tests.** `CVKEFridgeUITests` has one class for each area of the app. Each test starts the debug build in a
  data folder of its own, with a fixed date, and attaches screenshots. No test uses the network: the product lookup
  reads fixture files. `CVKEFridge/App/LaunchOptions.swift` has the launch arguments of the debug build, for example
  `-inventory sample`.

  ```sh
  xcodebuild test -project CVKEFridge.xcodeproj -scheme CVKEFridge -destination "platform=iOS Simulator,name=<iPhone>"
  ```

## Project structure

```text
cvkefridge-ios/
  project.yml                     XcodeGen project: the app, its unit tests, and the UI tests
  spec/                           Copy of the shared specification. Do not edit.
  spec.ref                        The cvkefridge commit of the copy in spec/
  CVKEFridgeCore/                 Swift package with the product rules, Foundation only
    Sources/CVKEFridgeCore/
      AppVersion.swift            The version label, for example 0.1.0 (1)
      CalendarDate.swift          Calendar dates (rule 2)
      Freshness.swift             Days left and freshness (rule 3)
      Product.swift               Product, category, and unit
      StorageArea.swift           Storage area and storage kind
      Batch.swift                 Batch and expiry date
      FoodTable.swift             Table of foods and the expiry estimate (rule 4)
      StorageHints.swift          Storage hint of a looked-up product (rule 8)
      UseFirst.swift              Use-first order and the plan of a use (rules 5 and 6)
      Change.swift                A change in the change log
      ChangeCodec.swift           A change as JSON text
      Inventory.swift             Replay of the change log (rule 7)
    Sources/CVKEFridgeFeatures/   The rules above the core, Foundation only. Port of the plain Kotlin of Android:
                                  Inventory, History, Content, Lookup, Reminder, Photo
    Tests/CVKEFridgeCoreTests/    One test file for each vector file, and Vectors.swift, which reads spec/
    Tests/CVKEFridgeFeaturesTests/  The ported tests of the Android app module
  CVKEFridge/
    App/                          App entry, launch arguments, the objects that live as long as the app
    Model/                        FridgeModel (the inventory state and its actions) and the service protocols
    Platform/                     Change log file, settings files, HTTP, scanner, photos, notifications, the day clock
    Design/                       Colours, spacing, type, brand shapes, motion, haptics, and components
    Shell/                        Tabs, navigation, sheets, messages with "Undo", and the shared form parts
    Screens/                      One folder for each screen
    Debug/                        Sample inventory and component gallery, debug build only
    Resources/                    App icon, colours, category symbols, string catalog, tables, and privacy manifest
  CVKEFridgeTests/                Unit tests of the app
  CVKEFridgeUITests/              UI tests, one class for each area
  docs/android-parity-plan.md     The plan of the port from Android
  scripts/
    update-spec.py                Updates and checks the copy in spec/
    export-captures.py            Screenshot export for CI
    make-category-symbols.py      Makes the symbols of dairy, meat, and bakery in the asset catalog
```

## Shared specification

The product rules and their test vectors are in the [cvkefridge](https://github.com/Glebenator/cvkefridge)
repository. The folder `spec/` is an exact copy of its `spec/` folder, and `spec.ref` names the commit of the copy.
Do not edit `spec/` or `spec.ref` by hand. To change a rule, change it in cvkefridge first. Then update the copy:

```sh
python3 scripts/update-spec.py <commit>
```

CI runs `python3 scripts/update-spec.py --check`. It fails if `spec/` is different from cvkefridge at the commit in
`spec.ref`.

## Documents

- The product documents (plan, glossary, and decisions) are in the
  [cvkefridge](https://github.com/Glebenator/cvkefridge) repository.
- [AGENTS.md](AGENTS.md): the rules for work on this app.

Report a problem or a request in [GitHub Issues](https://github.com/Glebenator/cvkefridge-ios/issues).
