# Before-you-build: SwiftUI multiplatform (macOS + iOS)

Tick every box before scaffolding a SwiftUI app that targets both platforms.

## Toolchain
- [ ] `swift --version` shows 6.1+. The corpus is verified on Swift 6.1.2.
- [ ] For iOS builds you need full Xcode 16.3+ — confirm `xcodebuild -version`. For macOS-only builds, Command Line Tools is sufficient.

## Package.swift
- [ ] `platforms:` lists both targets: `[.iOS(.v17), .macOS(.v14)]` (minimums for `@Observable` and `NavigationStack`).
- [ ] Shared library product does NOT depend on Hummingbird, AppKit, UIKit, or Combine. Only `Foundation`, the LLM client, `Observation`, and (in view files only) `SwiftUI`.

## State management
- [ ] You use `@Observable` + `@Bindable`, not `ObservableObject` + `@Published` + `@StateObject` (see EG-04).
- [ ] The view model is `@MainActor`.
- [ ] The view model does **not** `import SwiftUI` (see anti-pattern `anti-patterns/import-swiftui-in-viewmodel.md`).
- [ ] If the view model needs to mutate from a background task, mutations go through `await MainActor.run { ... }`.

## Cross-platform views
- [ ] You have a plan for the small set of iOS-only modifiers (`.navigationBarTitleDisplayMode(.inline)`, `.submitLabel(.send)`) and macOS-only scenes (`Settings`, `MenuBarExtra`). Wrap them with `#if os(...)` at the point of use, not in whole-file branches.
- [ ] Cross-platform layout uses `NavigationStack`, not the deprecated `NavigationView`.
- [ ] You do not use `UIViewRepresentable` / `NSViewRepresentable` in shared library code; if you need them, push them to the app shell.

## App shells
- [ ] macOS app shell is a SwiftPM executable target with `@main struct App: App`.
- [ ] iOS app shell is an Xcode iOS App project that adds the SwiftPM package as a local dependency. iOS source files (`@main App`, root view) live next to the package in `iosApp/` plus an `OPEN-IN-XCODE.md`. Do NOT commit a hand-written `.xcodeproj` (see anti-pattern `anti-patterns/hand-written-xcodeproj-pbxproj.md`).

## Run + test
- [ ] `swift build` builds the shared library AND the macOS executable on a Mac with CLT alone.
- [ ] `swift test` runs the view-model unit tests on macOS. The same code compiles for iOS (verified via Xcode).
- [ ] You accept the gotcha that `swift run` may not launch an interactive window without an `.app` bundle wrapper (see gotcha `gotchas/swiftui-builds-with-clt-but-cannot-launch.md`).

## Evidence
- Research: `01-research/05-swiftui-multiplatform.md` — full SwiftUI macOS/iOS reference.
- Planning: `02-planning/01-shared-package-strategy.md` — multiplatform package + app shell layout.
- Planning: `02-planning/02-xcode-decision.md` — when Xcode is mandatory.
- POC: `L6-swiftui-ios-app/`, `L-capstone-multiplatform-chat/` — full multiplatform examples.
