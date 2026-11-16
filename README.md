# CVKE Fridge for iOS

[![iOS CI](https://github.com/Glebenator/cvkefridge-ios/actions/workflows/ios.yml/badge.svg?branch=main)](https://github.com/Glebenator/cvkefridge-ios/actions/workflows/ios.yml?query=branch%3Amain)

A native iOS app for the food inventory of a fridge. The first build has one start screen and no features. It proves
that the project builds and that its tests run in CI. Built with SwiftUI and the iOS 26 design.

CVKE Fridge has three repositories:

| Repository | Contents |
|---|---|
| [cvkefridge](https://github.com/Glebenator/cvkefridge) | The product: plan, glossary, and decisions |
| [cvkefridge-android](https://github.com/Glebenator/cvkefridge-android) | The Android app |
| **cvkefridge-ios** | This repository: the iOS app, with the same product rules as Android |

## Status

- **Development build.** The app is not published. The bundle ID `com.example.cvkefridge` is a development ID.
- **Scope.** One static start screen. It shows the name, one line about the app, and the version.
- **Core rules.** The `CVKEFridgeCore` package has the product rules of `spec/rules.md`: calendar dates, freshness,
  the expiry estimate, the use-first order, the plan of a use, and the replay of the change log. No screen uses them
  yet.
- **CI.** The badge above shows the result of the newest run on `main`. Select it to see all runs.

### What CI checks

The workflow [`ios.yml`](.github/workflows/ios.yml) runs for each push to `main` and each pull request, on a
`macos-26` runner.

| Check | How | In CI |
|---|---|---|
| Copy of the shared specification | `python3 scripts/update-spec.py --check` | Yes |
| Product rules | `swift test` in `CVKEFridgeCore`, with each case in `spec/vectors/` | Yes |
| App and UI test build | `xcodebuild build-for-testing`, without signing | Yes |
| The shell in light mode | `ShellUITests` | Yes |
| The shell in dark mode | `ShellUITests` | Yes |
| Real iPhone checks | Manual | No |

Each run uploads the screenshots of the shell tests as the `ios-captures` artifact.

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
- **UI tests.** `ShellUITests` starts the debug build with the sample inventory in a data folder of its own. It
  checks the tabs, the add button, a form in a sheet, and a message with "Undo", and it attaches screenshots.
  `CVKEFridge/App/LaunchOptions.swift` has the launch arguments of the debug build, for example `-inventory sample`.

  ```sh
  xcodebuild test -project CVKEFridge.xcodeproj -scheme CVKEFridge -destination "platform=iOS Simulator,name=<iPhone>"
  ```

## Project structure

```text
cvkefridge-ios/
  project.yml                     XcodeGen project: the app and the UI tests
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
    Tests/CVKEFridgeCoreTests/    One test file for each vector file, and Vectors.swift, which reads spec/
  CVKEFridge/
    App/                          App entry
    Screens/                      The start screen
    Design/                       Colour tokens and spacing
    Resources/                    App icon, accent colour, category symbols, string catalog, and privacy manifest
  CVKEFridgeUITests/              The UI test
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
