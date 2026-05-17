# Anti-pattern: reaching for `xcodebuild` when `swift build` suffices for a SwiftUI macOS POC

**Category**: anti-pattern

## Broken approach
Spinning up an Xcode project for a SwiftUI macOS POC because "SwiftUI requires Xcode":

```
mkdir ChatMacApp && cd ChatMacApp
# Open Xcode, File > New > Project > macOS > App
# ... 20 minutes of clicking ...
xcodebuild -scheme ChatMacApp build
```

## Why it fails (or wastes time)
- On macOS 15 + Swift 6.1.2 CLT, `swift build` against a `Package.swift` with `import SwiftUI` and `@main struct App: App` compiles successfully (verified probe: exit 0 in 34.67s). No Xcode required for build verification.
- Xcode projects introduce a second source of truth (`.xcodeproj/project.pbxproj`) that drifts from `Package.swift`. Two systems, two `Package.resolved` files possible, double the maintenance.
- The whole POC progression (L1–L5, capstone macOS) avoids Xcode entirely. Adding it for L5 would have been overkill.
- iOS targets are a different story — they DO require Xcode (simulator runtimes, code signing). But that does not extend to macOS SwiftUI.

## Right approach
For macOS SwiftUI: `swift build` is enough for build verification, and `swift test` covers the view-model unit tests. The actual running of the binary (if you want a window) is documented as a manual step with known limitations (see gotcha `gotchas/swiftui-builds-with-clt-but-cannot-launch.md`).

```swift
// Package.swift — that's all
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L5-swiftui-macos-app",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ChatMacApp", targets: ["ChatMacApp"])],
    dependencies: [.package(path: "../L2-anthropic-client")],
    targets: [
        .target(name: "ChatAppCore", dependencies: [/* L2 */]),
        .executableTarget(name: "ChatMacApp", dependencies: ["ChatAppCore"]),
        .testTarget(name: "ChatAppCoreTests", dependencies: ["ChatAppCore"])
    ]
)
```

```bash
swift build           # ← verifies SwiftUI macOS compiles
swift test            # ← verifies view-model logic
swift run ChatMacApp  # ← attempts to launch; see gotchas/swiftui-builds-with-clt-but-cannot-launch.md
```

## Variants and trade-offs
- **iOS**: Xcode is still mandatory because there is no SwiftPM path to simulator runtimes. The capstone keeps iOS as bare `.swift` files in `iosApp/` plus an `OPEN-IN-XCODE.md`.
- **Code-signed distribution macOS app**: yes, you need Xcode at the end of the pipeline. But not for development iteration on the SwiftUI code itself.

## Evidence
- Planning: `02-planning/02-xcode-decision.md` §1-4 lines 1-71 — explicit decision: "Proceed through L1–L4 with CLT. At L5 entry: run the verification probe. ... If L5 verification succeeds: proceed without Xcode."
- Research: `01-research/05-swiftui-multiplatform.md` §8 lines 359-381 — verified probe; `swift build` exit 0 on `/tmp/swift-research-probe/swiftui-test/`.
- POC: `L5-swiftui-macos-app/Package.swift:1-32` — single Package.swift; no `.xcodeproj/`.
- POC: `L5-swiftui-macos-app/README.md:31-33` — "A research probe confirmed SwiftUI macOS apps compile with `swift build` on Command Line Tools alone."
- See also: gotcha `gotchas/swiftui-builds-with-clt-but-cannot-launch.md`, ADR `decision-records/adr-009-iosapp-source-files-not-xcodeproj.md`.
