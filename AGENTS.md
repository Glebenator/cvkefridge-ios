# Project rules: CVKE Fridge for iOS

CVKE Fridge has three repositories. This repository is the native iOS app.

- [cvkefridge](https://github.com/Glebenator/cvkefridge): the product. Plan, glossary, and decisions. Product rules
  there apply to this app.
- [cvkefridge-android](https://github.com/Glebenator/cvkefridge-android): the Android app.
- [cvkefridge-ios](https://github.com/Glebenator/cvkefridge-ios): this repository.

## Product

- Build a native iOS app for publication. It has the same product rules and behaviour as the Android app.
- Use ASD-STE100 Simplified Technical English for instructions and documentation.
- Implement only the agreed feature scope. Do not add inactive controls or simulated production data.
- Record each intended difference from Android in a decision record in the cvkefridge repository.
- Commit and push only when the user asks.

## Structure

- Use Swift, SwiftUI, and the iOS 26 design. Generate the Xcode project with XcodeGen from `project.yml`.
- Keep the product rules in the `CVKEFridgeCore` Swift package. It uses Foundation only. Each file in it has a file of
  the same name in the `:core` module of cvkefridge-android, with the same behaviour and the same test cases.
- The core rules follow `spec/rules.md`. If the words are not clear, `spec/tools/vectors.py` and the vectors in
  `spec/vectors/` decide.
- `spec/` is an exact copy of the `spec/` folder of cvkefridge, at the commit in `spec.ref`. Do not edit `spec/` or
  `spec.ref`. To change a rule, change it in the cvkefridge repository first. Then run
  `python3 scripts/update-spec.py <commit>` here.
- Keep UIKit and SwiftUI objects out of `CVKEFridgeCore`.
- Use observable models with one-way data flow. Pass dependencies through initializers.
- Add a dependency only when it solves a current problem. Do not add unused libraries.
- Use structured concurrency with a defined owner for each task. Do not start detached work that nothing cancels.

## Design and access

- Use system components, the app colour tokens, and standard iOS navigation.
- Support light and dark appearance, Dynamic Type up to the largest accessibility size, VoiceOver, and rotation.
- Make touch targets at least 44 points.
- Put visible text in the string catalog. Format numbers for the user's locale.

## Performance and privacy

- Keep disk access and expensive calculations off the main actor.
- Avoid continuous animation and unnecessary view updates. Measure with Instruments before adding performance complexity.
- Do not add analytics or network transmission without an agreed product requirement.
- Treat simulator results as functional evidence only. Measure battery use and speed on a real iPhone.

## Tests and delivery

- Run `swift test` in `CVKEFridgeCore` for changes to the product rules.
- The core tests run each case of the vectors in `spec/vectors/` and compare the complete expected result. Do not
  skip, weaken, or change a vector. If a vector seems wrong, report it and correct it in cvkefridge.
- Run the UI test on a simulator for functional changes.
- Add unit tests only for calculations or failure cases that the UI test cannot cover well.
- Restore the simulator appearance and text size after tests.
- The workflow `.github/workflows/ios.yml` compares `spec/` with cvkefridge, and runs the core tests and the UI test,
  for each push to `main` and each pull request. Check its result before you report a change as verified.
- Inspect light mode, dark mode, and the largest text size after layout changes.
- Report what was tested, what failed, and what still needs a real iPhone.
- Keep generated output, the generated Xcode project, signing data, and Xcode user state out of Git.
- Before publication, replace the development bundle IDs, set up signing, and complete the App Store privacy details.

## Issues

- Issues for the iOS app are in GitHub Issues for `Glebenator/cvkefridge-ios`. Use the `gh` CLI.
- A feature that both apps need has a parent issue in `Glebenator/cvkefridge` and one sub-issue for each app.
- Use the triage labels `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`.
