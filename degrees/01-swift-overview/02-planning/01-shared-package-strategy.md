# Shared Package Strategy — L5 / L6 / capstone

> Grounded in research: `01-research/02-swiftpm-and-tooling.md` §5, `01-research/05-swiftui-multiplatform.md` §7.

## 1. The problem

By L5 we have:
- An `AnthropicClient` library (L2) used by L3 (CLI) and L4 (server).
- A streaming extension and SSE parser (L3) usable by clients.
- A `@MainActor` `ChatViewModel` introduced in L5 that owns the client and exposes streaming UI state.

By L6 we need to:
- Run that same view model in an iOS app.
- Run the same `AnthropicClient` in iOS, macOS, and (capstone) Linux (for the Docker server).

Three things must work simultaneously:
1. `swift build` on macOS CLT produces the macOS app target.
2. Xcode builds the iOS target consuming the same shared code.
3. `swift build` inside a Linux Docker container builds the backend.

The strategy below is the single multiplatform SwiftPM package that supports all three.

## 2. Recommended structure: one package, three targets, two app shells

Promote shared code into a single multiplatform SwiftPM package — proposed name `ChatCore` — that lives at the capstone level (and is consumed by L5 and L6 as a local path dependency starting at L6). The Hummingbird-using backend executable lives next to it inside the same package.

```
shared-package/                            ← lives in L-capstone (or earlier if promoted)
├── Package.swift
├── Sources/
│   ├── ChatCore/                          ← portable: client, models, view models
│   │   ├── AnthropicClient.swift
│   │   ├── Models/...
│   │   ├── SSEParser.swift
│   │   └── ChatViewModel.swift            ← @Observable @MainActor — portable
│   └── ChatBackend/                       ← executable, depends on ChatCore + Hummingbird
│       └── main.swift
└── Tests/
    └── ChatCoreTests/
```

App shells live OUTSIDE the package because they include `@main`, app icons, Info.plist, entitlements, and (for iOS) an Xcode project:

```
L5-swiftui-macos-app/                      ← consumes ChatCore as a local path dep
├── Package.swift
└── Sources/ChatMac/
    └── ChatMacApp.swift                   ← @main App; imports ChatCore

L6-swiftui-ios-app/
├── ChatiOS.xcodeproj/                     ← Xcode adds the ChatCore package
└── ChatiOS/
    └── ChatiOSApp.swift                   ← @main App; imports ChatCore
```

### Targets-in-package vs targets-in-app-shells

| Lives in the shared package | Lives in the app shell |
|------------------------------|------------------------|
| `AnthropicClient` (actor)    | `@main struct App: App` |
| Codable request/response types | `WindowGroup` / iOS scene |
| `SSEParser`                  | App icon, Info.plist, entitlements |
| `ChatViewModel` (`@MainActor @Observable`) | Settings scene (macOS) |
| `ChatMessage`, role enum, error enum | `NavigationStack` root (iOS) |
| Hummingbird backend executable | Anything that needs an Xcode project |

Rule of thumb: anything that imports SwiftUI views with `#if os(macOS)` / `#if os(iOS)` guards lives in the app shell. The view *model* — which mutates plain Swift state — lives in the package and is platform-portable.

## 3. The actual `Package.swift` skeleton

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ChatCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        // Portable library — used by macOS shell, iOS shell, and backend
        .library(name: "ChatCore", targets: ["ChatCore"]),
        // Server executable — built on macOS for local dev, on Linux in Docker
        .executable(name: "chat-backend", targets: ["ChatBackend"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        // ── ChatCore: portable library ─────────────────────────────────
        // No SwiftUI imports here. No AppKit. No UIKit.
        // Uses only Foundation, Observation, and Swift concurrency.
        .target(
            name: "ChatCore",
            dependencies: []
        ),

        // ── ChatBackend: executable for the Hummingbird proxy ──────────
        // Linux-buildable. No SwiftUI dependency.
        .executableTarget(
            name: "ChatBackend",
            dependencies: [
                "ChatCore",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // ── Tests ──────────────────────────────────────────────────────
        .testTarget(
            name: "ChatCoreTests",
            dependencies: ["ChatCore"]
        ),
        .testTarget(
            name: "ChatBackendTests",
            dependencies: [
                "ChatBackend",
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ]
        ),
    ]
)
```

Notes:
- `platforms:` lists macOS 15 AND iOS 18 — this is what makes the package consumable from the Xcode iOS target. Without iOS in `platforms:`, Xcode rejects it.
- `ChatCore` target has zero external dependencies. This keeps the dep graph minimal for the iOS app and lets Linux builds (backend) skip everything iOS-specific.
- The backend is its own product so the iOS / macOS apps do not transitively pull in Hummingbird and SwiftNIO. They only depend on `ChatCore`.

## 4. How the macOS app shell consumes it

In `L5-swiftui-macos-app/Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ChatMac",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../shared-package"),     // relative path
    ],
    targets: [
        .executableTarget(
            name: "ChatMac",
            dependencies: [
                .product(name: "ChatCore", package: "shared-package"),
            ]
        ),
    ]
)
```

Then in `ChatMacApp.swift`:

```swift
import SwiftUI
import ChatCore

@main
struct ChatMacApp: App {
    @State private var viewModel = ChatViewModel()  // from ChatCore

    var body: some Scene {
        WindowGroup("Chat") {
            ContentView(viewModel: viewModel)
        }
        #if os(macOS)
        Settings { SettingsView() }
        #endif
    }
}
```

`swift run ChatMac` builds and runs from the L5 directory.

## 5. How the iOS app shell consumes it

iOS targets cannot be built with `swift build` (no simulator runtimes without Xcode — research §2 §8). So L6 is an Xcode project, and the Xcode project consumes the shared package via **File > Add Package Dependencies > Add Local…**, pointing to `../shared-package`.

```
ChatiOS.xcodeproj
├── ChatiOS                        ← iOS App target
│   ├── ChatiOSApp.swift
│   ├── Views/
│   │   ├── ChatScreen.swift       ← imports ChatCore; uses NavigationStack
│   │   └── InputBar.swift
│   ├── Info.plist
│   └── ChatiOS.entitlements       ← com.apple.security.network.client
└── Package Dependencies
    └── shared-package (local)     ← provides ChatCore product
```

In `ChatiOSApp.swift`:

```swift
import SwiftUI
import ChatCore

@main
struct ChatiOSApp: App {
    @State private var viewModel = ChatViewModel()  // SAME type as the macOS app uses

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatScreen(viewModel: viewModel)
            }
        }
    }
}
```

The Xcode project's `Package.resolved` lives alongside the `.xcodeproj` and pins transitive deps. Commit it.

## 6. `#if os(macOS)` / `#if os(iOS)` guard anticipation

Per `01-research/05-swiftui-multiplatform.md` §2 and §5, these are the SwiftUI surfaces we expect to need guards for. The view *model* in `ChatCore` should need NO guards — that is the test of whether ChatCore is genuinely portable.

| Concern | Guard | Notes |
|---------|-------|-------|
| Settings scene | `#if os(macOS)` | iOS has no `Settings` scene type |
| MenuBarExtra | `#if os(macOS)` | macOS only |
| `.windowStyle(.hiddenTitleBar)` | `#if os(macOS)` | not available on iOS |
| `.navigationBarTitleDisplayMode()` | `#if os(iOS)` | UIKit-rooted |
| `.safeAreaInset(edge: .bottom)` for keyboard | `#if os(iOS)` only when iOS-specific behavior diverges | macOS has no soft keyboard |
| `UIPasteboard` / `NSPasteboard` access | `#if os(iOS) / #if os(macOS)` | distinct APIs |
| `UIViewRepresentable` / `NSViewRepresentable` | per-platform | only if bridging needed |

Guards should appear in the **app shells**, not in `ChatCore`. If a guard is needed inside `ChatCore`, that is a signal that the abstraction is wrong and that piece should be pushed up to the shell.

## 7. Promotion plan: when does the shared package come into existence?

To avoid premature abstraction, promote in stages:

| Stage | Action |
|-------|--------|
| L2 | `AnthropicClient` lives in its own SwiftPM package — single-platform (macOS). |
| L3 | L3 consumes L2 via `.package(path: "../L2-anthropic-client")`. SSE parser lives in L3. |
| L4 | L4 consumes L2. Backend logic lives in L4. |
| L5 | L5 consumes L2 directly. The `ChatViewModel` and the SSE parser are duplicated into L5 (small, ~50 lines combined). This is intentional — we accept duplication until we see the actual iOS need. |
| L6 | **Promotion event.** Create the `shared-package/` (called ChatCore) at this stage. Migrate from L2 source into ChatCore as the source of truth. Update L5 to consume ChatCore instead of L2. L6 consumes ChatCore from the start. |
| capstone | ChatCore + ChatBackend become the canonical assembly. L1–L6 remain as historical learning artifacts. |

Rationale: the rule of three. We only have proof of needing shared code at the L6 stage. Building the shared package earlier risks designing the wrong abstraction.

## 8. Linux consideration for the backend

For the capstone Docker image, the backend builds on Linux Swift. `ChatCore` must be Linux-clean:

- ✅ Use only `Foundation` types that exist on Linux (`URL`, `URLSession`, `JSONEncoder`, `JSONDecoder` — all available on Swift 6 Linux as of 2026).
- ❌ Do NOT import `AppKit`, `UIKit`, `Combine`, `SwiftUI` in `ChatCore`.
- ⚠ `URLSession` on Linux uses a non-NIO implementation that historically lacked some features (e.g., HTTPS proxies). Streaming via `URLSession.bytes(for:)` works on Linux as of Swift 6.0+.

Risk: the iOS view model uses `Observation` (`@Observable` macro). `Observation` is part of the standard library since Swift 5.9 and available on Linux. Verified by checking Swift Evolution SE-0395 status and Swift 6 release notes.
