# L5 — swiftui-macos-app

SwiftUI macOS chat client for Claude. Streaming UI, multi-turn history.

## What this teaches
- SwiftUI macOS app structure: `@main App`, `WindowGroup`, `Scene`, `windowResizability`
- @Observable view model with `@Bindable` view bindings
- MainActor-bound state with async streaming updates
- That SwiftUI macOS apps compile with **Command Line Tools only** (no full Xcode needed for build verification)
- Clean separation: views thin, view model fat, business logic in library target (testable)

## Build and run
```bash
export ANTHROPIC_API_KEY=...
swift build       # confirms compile (CLT-only is fine)
swift run ChatMacApp
# A real macOS window opens — type and chat.
```

## Run tests (no API key required)
```bash
swift test        # all ChatViewModel tests pass
```

## Architecture
- `Sources/ChatAppCore/` — library target. Holds `LLMService`, `ChatMessage`, `ChatViewModel`. Fully unit-tested.
- `Sources/ChatMacApp/` — executable target. Holds the SwiftUI views (`@main App`, `ContentView`, `MessageRow`, `InputBar`). View code is intentionally minimal; logic lives in the view model.

## Dependencies
- `../L2-anthropic-client` (sibling POC, SwiftPM relative path)

## Xcode? Not required for build verification.
A research probe confirmed SwiftUI macOS apps compile with `swift build` on Command Line Tools alone. iOS (L6) still needs Xcode; SwiftUI for macOS does not, for build purposes.
