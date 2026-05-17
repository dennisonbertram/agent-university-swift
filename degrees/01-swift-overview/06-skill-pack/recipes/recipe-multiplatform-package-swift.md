# Recipe — `Package.swift` for iOS+macOS with Library + Executables

[Back to index](../index.md) | See also: [lesson-09-multiplatform-swift-packages.md](../lessons/lesson-09-multiplatform-swift-packages.md) | Pattern: `patterns/multiplatform-spm-package.md`

## Use this when

You need a single SwiftPM package that builds for both iOS 17+ and macOS 14+, exposing a shared library and platform-specific executables.

## Canonical `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L-capstone-multiplatform-chat",
    platforms: [
        .iOS(.v17),     // @Observable requires iOS 17+
        .macOS(.v14)    // @Observable requires macOS 14+, Hummingbird 2.x requires macOS 14+
    ],
    products: [
        .library(name: "ChatCore", targets: ["ChatCore"]),
        .executable(name: "chat-backend", targets: ["chat-backend"]),
        .executable(name: "ChatMacApp", targets: ["ChatMacApp"])
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client"),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        // Shared library — compiles for iOS + macOS
        // No Hummingbird, no AppKit, no UIKit, no Combine
        .target(
            name: "ChatCore",
            dependencies: [
                .product(name: "AnthropicClient", package: "L2-anthropic-client")
            ]
        ),

        // macOS-only executable: the SwiftUI chat app
        .executableTarget(
            name: "ChatMacApp",
            dependencies: ["ChatCore"]
        ),

        // macOS/Linux executable: the Hummingbird backend
        .executableTarget(
            name: "chat-backend",
            dependencies: [
                "ChatCore",
                .product(name: "Hummingbird", package: "hummingbird")
            ]
        ),

        // Tests run on macOS; the same code compiles for iOS
        .testTarget(
            name: "CapstoneTests",
            dependencies: [
                "ChatCore",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird")
            ]
        )
    ]
)
```

Evidence: `L-capstone-multiplatform-chat/Package.swift:5-64`.

## What belongs where

| Target | Allowed imports |
|--------|----------------|
| `ChatCore` | `Foundation`, `AnthropicClient`, `Observation`, `SwiftUI` (in view files only) |
| `ChatMacApp` | `SwiftUI`, `ChatCore` |
| `chat-backend` | `Hummingbird`, `ChatCore` |
| `CapstoneTests` | `Testing`, `Hummingbird`, `HummingbirdTesting`, `ChatCore` |

**Forbidden in `ChatCore`:** `import AppKit`, `import UIKit`, `import Combine`, `import Hummingbird`.

## iOS app shell

iOS apps cannot be built from `swift build`. Keep iOS source files in `iosApp/` (outside the SPM target tree):

```
iosApp/
  ChatIOSApp.swift        # @main struct ChatIOSApp: App
  RootView.swift          # iOS root scene
  OPEN-IN-XCODE.md       # step-by-step Xcode wiring instructions
```

Evidence: `L-capstone-multiplatform-chat/iosApp/OPEN-IN-XCODE.md`; `decision-records/adr-009-iosapp-source-files-not-xcodeproj.md`.
