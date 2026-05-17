# Pattern: one multiplatform SwiftPM package + per-platform app shells

**Category**: pattern

## What
Share core logic (view model, models, services, even SwiftUI views that compile on both platforms) in a single SwiftPM package that declares `platforms: [.iOS(.v17), .macOS(.v14)]`. Keep `@main App` structs, Info.plist, entitlements, and Xcode-only artifacts OUT of the package, in per-platform app shells. macOS apps reference the package via `.package(path: "...")` for `swift build`; iOS apps add the same package as a local Xcode dependency.

## When to apply
- Any project that needs to ship the same chat (or any) logic on macOS and iOS.
- When you want `swift test` on a Mac to cover the same code that the iOS app will run.

## Canonical code

`Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L-capstone-multiplatform-chat",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ChatCore", targets: ["ChatCore"]),
        .executable(name: "chat-backend", targets: ["chat-backend"]),
        .executable(name: "ChatMacApp", targets: ["ChatMacApp"])
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client"),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0")
    ],
    targets: [
        // Cross-platform: no Hummingbird, no platform-specific imports
        .target(name: "ChatCore",
                dependencies: [.product(name: "AnthropicClient", package: "L2-anthropic-client")]),
        // macOS-only executable for swift run
        .executableTarget(name: "ChatMacApp", dependencies: ["ChatCore"]),
        // ... backend target also depends only on ChatCore + Hummingbird (no SwiftUI)
    ]
)
```

What lives where:

| In the shared library                           | In the app shell                    |
|--------------------------------------------------|-------------------------------------|
| `AnthropicClient` / `BackendLLMService`         | `@main struct App: App`             |
| `ChatViewModel` (`@MainActor @Observable`)      | `WindowGroup` or iOS scene root      |
| `ChatMessage`, `Role` value types               | App icon, Info.plist, entitlements  |
| `ChatScreen`, `MessageRow`, `InputBar` (SwiftUI views with `#if` guards) | iOS Xcode project, simulator scheme |
| Backend executable target                       | Anything that needs an `.xcodeproj` |

## Variants and trade-offs
- iOS apps cannot be built from `swift build` (no simulator). The iOS shell remains an Xcode project that points at the SwiftPM package.
- The capstone keeps the iOS shell as bare `.swift` files in `iosApp/` plus an `OPEN-IN-XCODE.md` describing how to drop them into a new Xcode iOS App project. See ADR `decision-records/adr-009-iosapp-source-files-not-xcodeproj.md`.
- Tests run only on macOS but the code under test compiles for both — sufficient assurance for logic. UI snapshot tests would still need Xcode/iOS simulator.
- Backend product depends on Hummingbird; iOS/macOS app products do NOT — both transit through `ChatCore` only. This keeps the iOS dep graph minimal.

## Evidence
- POC: `L-capstone-multiplatform-chat/Package.swift:5-64` — full multiplatform manifest with 3 products.
- POC: `L6-swiftui-ios-app/Package.swift:5-28` — earlier `.iOS + .macOS` shared library that L6 pioneered.
- POC: `L6-swiftui-ios-app/iosApp/ChatIOSApp.swift`, `L6-swiftui-ios-app/iosApp/RootView.swift` — Xcode-ready source files outside the SwiftPM target tree.
- POC: `L-capstone-multiplatform-chat/iosApp/OPEN-IN-XCODE.md` — step-by-step Xcode wiring.
- Planning: `02-planning/01-shared-package-strategy.md` — the full strategy doc.
- Research: `01-research/02-swiftpm-and-tooling.md` §5 lines 159-198 — multiplatform SwiftPM mechanics; CLT-vs-Xcode capability matrix.
- See also: pattern `patterns/cross-platform-swiftui-guards.md`, ADR `decision-records/adr-009-iosapp-source-files-not-xcodeproj.md`.
