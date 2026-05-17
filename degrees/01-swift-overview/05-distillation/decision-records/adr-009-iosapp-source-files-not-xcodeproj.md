# ADR-009: Ship the iOS app as `iosApp/*.swift` + `OPEN-IN-XCODE.md`, not as a committed `.xcodeproj`

**Date**: 2026-05-16

## Decision
The L6 and capstone iOS apps live as bare `.swift` source files in an `iosApp/` subdirectory next to the SwiftPM package, accompanied by an `OPEN-IN-XCODE.md` walkthrough. No `.xcodeproj` is committed.

## Alternatives considered
- **Commit a hand-authored or Xcode-generated `.xcodeproj`** — fully turn-key.
- **Use `swift package generate-xcodeproj` (now deprecated) on demand.**
- **Adopt the Xcode 16 "App project + SwiftPM as local dep" structure and commit only the `.xcodeproj` minus build settings.**

## Why source files + walkthrough
1. **`.xcodeproj/project.pbxproj` is unstable.** Xcode rewrites the file format and UUIDs on every Save. Committing it produces merge conflicts and breaks across Xcode versions.
2. **The corpus does not have CI for iOS.** Without iOS CI to keep an `.xcodeproj` valid, a committed project goes stale quickly.
3. **The SwiftPM package is the source of truth.** `ChatCore` (the library) and `BackendLLMService` (URLSession-backed) compile and test on macOS. The iOS app shell is < 50 lines of code that any iOS developer can drop into a fresh Xcode project in 3 minutes.
4. **Teaching value.** The walkthrough makes explicit what an iOS developer would otherwise do tacitly: create project, add local package dep, replace generated entry points, set env vars in scheme.

## Trade-offs accepted
- **One-time friction.** Each new contributor who wants to run the iOS app must follow the walkthrough (~5 minutes) rather than just opening a checked-in project.
- **No automated iOS build verification in `swift test`.** The shared `ChatViewModel` is verified to compile cross-platform via `swift build` on macOS targeting both platforms; the iOS app shell is verified by manual Xcode build.

## Evidence
- POC: `L6-swiftui-ios-app/iosApp/ChatIOSApp.swift:1-22` — bare `@main` source file.
- POC: `L6-swiftui-ios-app/iosApp/RootView.swift` — bare root view.
- POC: `L6-swiftui-ios-app/OPEN-IN-XCODE.md:1-22` — 9-step walkthrough.
- POC: `L-capstone-multiplatform-chat/iosApp/OPEN-IN-XCODE.md:1-13` — 5-step walkthrough plus env-var setup.
- POC: No `.xcodeproj` is committed in either POC root.
- Planning: `02-planning/02-xcode-decision.md` §4 lines 52-61 — explicit gating decision: "For L6, Xcode install is required. Defer the install request until L6 begins."
- See also: anti-pattern `anti-patterns/hand-written-xcodeproj-pbxproj.md`.
