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
- **CI.** The badge above shows the result of the newest run on `main`. Select it to see all runs.

### What CI checks

The workflow [`ios.yml`](.github/workflows/ios.yml) runs for each push to `main` and each pull request, on a
`macos-26` runner.

| Check | How | In CI |
|---|---|---|
| Product rules | `swift test` in `CVKEFridgeCore` | Yes |
| App and UI test build | `xcodebuild build-for-testing`, without signing | Yes |
| Start screen in light mode | `StartUITests/test1StartScreen` | Yes |
| Start screen in dark mode | `StartUITests/test1StartScreen` | Yes |
| Real iPhone checks | Manual | No |

Each run uploads the screenshots of the start screen as the `ios-captures` artifact.

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

- **Core tests.** In `CVKEFridgeCore`, run `swift test`. They repeat the Android tests of the same rules. They also run
  on Linux with the Swift toolchain.
- **UI test.** It starts the app, checks the title and the version, and attaches a screenshot.

  ```sh
  xcodebuild test -project CVKEFridge.xcodeproj -scheme CVKEFridge -destination "platform=iOS Simulator,name=<iPhone>"
  ```

## Project structure

```text
cvkefridge-ios/
  project.yml                     XcodeGen project: the app and the UI tests
  CVKEFridgeCore/                 Swift package, Foundation only
    AppVersion.swift              The version label, for example 0.1.0 (1)
  CVKEFridge/
    App/                          App entry
    Screens/                      The start screen
    Design/                       Colour tokens and spacing
    Resources/                    App icon, accent colour, string catalog, and privacy manifest
  CVKEFridgeUITests/              The UI test
  scripts/                        Screenshot export for CI
```

## Documents

- The product documents (plan, glossary, and decisions) are in the
  [cvkefridge](https://github.com/Glebenator/cvkefridge) repository.
- [AGENTS.md](AGENTS.md): the rules for work on this app.

Report a problem or a request in [GitHub Issues](https://github.com/Glebenator/cvkefridge-ios/issues).
