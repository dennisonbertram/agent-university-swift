# Example — L6: `Package.swift` Declaring iOS+macOS

[Back to index](../index.md) | POC: `degrees/01-swift-overview/03-pocs/L6-swiftui-ios-app/Package.swift`

## What this example demonstrates

- A SwiftPM package with both `.iOS(.v17)` and `.macOS(.v14)` in `platforms:`.
- Separation of the shared library from Xcode-only iOS app sources.
- Local path dependency on the sibling `L2-anthropic-client`.

## Full `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L6-swiftui-ios-app",
    platforms: [
        .iOS(.v17),     // @Observable requires iOS 17+
        .macOS(.v14)    // @Observable requires macOS 14+
    ],
    products: [
        // The shared library that compiles for BOTH platforms
        .library(name: "ChatCoreShared", targets: ["ChatCoreShared"]),
        // macOS app executable — does NOT appear in the iOS app
        .executable(name: "ChatMacApp", targets: ["ChatMacApp"]),
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client"),
    ],
    targets: [
        // ── Shared library ──────────────────────────────────────────────────
        // No Hummingbird. No AppKit. No UIKit. No Combine.
        // Imports: Foundation, Observation, AnthropicClient, SwiftUI (views only)
        .target(
            name: "ChatCoreShared",
            dependencies: [
                .product(name: "AnthropicClient", package: "L2-anthropic-client"),
            ]
        ),

        // ── macOS executable ────────────────────────────────────────────────
        // Contains @main App, WindowGroup, macOS-specific scene modifiers
        .executableTarget(
            name: "ChatMacApp",
            dependencies: ["ChatCoreShared"]
        ),

        // ── Tests run on macOS — same code compiles for iOS ─────────────────
        .testTarget(
            name: "ChatCoreSharedTests",
            dependencies: ["ChatCoreShared"]
        ),
    ]
)
```

Source: `L6-swiftui-ios-app/Package.swift:5-28`.

## iOS app shell (outside the SPM target tree)

```
L6-swiftui-ios-app/
  Package.swift                              ← SPM package
  Sources/
    ChatCoreShared/                          ← shared library (iOS + macOS)
      ChatViewModel.swift                    ← @MainActor @Observable, no import SwiftUI
      LLMService.swift
      Views/
        ChatScreen.swift                     ← #if os(iOS) guards
        InputBar.swift
    ChatMacApp/                             ← macOS @main app
      ChatMacApp.swift
  Tests/
    ChatCoreSharedTests/
      ChatViewModelTests.swift
      RegressionTests.swift                  ← REGRESSION-002: no import SwiftUI
  iosApp/                                   ← NOT part of SPM; Xcode-ready files
    ChatIOSApp.swift                         ← @main App for iOS
    RootView.swift
    OPEN-IN-XCODE.md                        ← step-by-step Xcode wiring
```

The `iosApp/` directory contains Swift source files that an Xcode iOS project pulls in as file references. No `.xcodeproj` is committed.

## What to notice

1. `platforms:` lists both targets. The shared library target must compile for both; the `ChatMacApp` executable is macOS-only but the toolchain doesn't restrict it.

2. `ChatCoreShared` depends only on `AnthropicClient`. It does NOT depend on Hummingbird — that stays out of the iOS dependency graph.

3. `swift build` and `swift test` on macOS exercise the shared code. iOS verification requires Xcode + simulator.

4. The `REGRESSION-002` test in `ChatCoreSharedTests` reads `ChatViewModel.swift` from disk and asserts `import SwiftUI` is absent. Evidence: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/RegressionTests.swift:60-108`.
