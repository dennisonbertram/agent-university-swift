# L6 — swiftui-ios-app

Multiplatform SwiftPM library (iOS 17 + macOS 14) for a Claude chat client, plus iOS app source files ready to drop into Xcode.

## What this teaches
- Multiplatform SwiftPM package declaration (`platforms: [.iOS(.v17), .macOS(.v14)]`)
- Cross-platform SwiftUI patterns: which APIs are shared, which need `#if os(iOS)` guards
- Keeping the view model UI-framework-free (no `import SwiftUI`) so it ports cleanly
- The iOS app integration story: library is the canonical artifact; the Xcode project is thin

## What's in the box
- `Sources/ChatCoreShared/` — the library: LLMService, ChatViewModel, ChatScreen, MessageRow, InputBar. All public, all cross-platform.
- `iosApp/` — Swift source files (`ChatIOSApp.swift`, `RootView.swift`) ready to drop into an Xcode iOS App project.
- `OPEN-IN-XCODE.md` — step-by-step to wrap iosApp/ in a real Xcode project and run on Simulator.

## Build and test (on macOS, no Xcode required)
```bash
swift build      # compiles ChatCoreShared targeting macOS
swift test       # runs ChatViewModel tests
```

## Run the iOS app (Xcode required)
See `OPEN-IN-XCODE.md`.

## Dependencies
- `../L2-anthropic-client` (sibling POC, SwiftPM relative path)
