# POC Plan — Swift Overview

Progressive levels. Each adds ONE concept and reuses everything below it. Levels L5/L6/L-capstone require full Xcode to build; L1–L4 build on Swift Command Line Tools.

| Level | POC slug | New concept | Reuses | Xcode? |
|-------|----------|-------------|--------|--------|
| L1 | `L1-hello-spm` | SwiftPM exec target, `swift run`, `swift test`, swift-testing | — | No |
| L2 | `L2-anthropic-client` | Library target, protocols, generics, Codable, Anthropic Messages API (sync) | L1 | No |
| L3 | `L3-cli-chat` | `swift-argument-parser`, streaming via `AsyncThrowingStream`, actors, cancellation | L1, L2 | No |
| L4 | `L4-hummingbird-tool-service` | Hummingbird routing/middleware, server-side LLM proxy, JSON I/O | L1–L3 | No |
| L5 | `L5-swiftui-macos-app` | SwiftUI for macOS, `@Observable`, window/menu, streaming UI updates | L1–L3 | Yes |
| L6 | `L6-swiftui-ios-app` | SwiftUI for iOS, `NavigationStack`, multiplatform SwiftPM package, code reuse | L1–L3, L5 | Yes |
| L-capstone | `L-capstone-multiplatform-chat` | Unified app: shared core + macOS shell + iOS shell + Hummingbird backend, with tests, Dockerfile for backend | L1–L6 | Yes |

Each level produces:
- A working SwiftPM project (or, for L5/L6/capstone, an Xcode-buildable project generated from SwiftPM).
- Tests using swift-testing (where the target supports it — UI POCs may need XCTest for UI-test coverage).
- A README explaining the new concept and how to run it.
- A git commit trail (red/green/regression for feature work).

## L5/L6/capstone build gate

Because the host machine has only Swift Command Line Tools, the user must install full Xcode before L5 can be build-verified. The coordinator will pause before L5 to confirm the install. If Xcode is unavailable at that point, the UI POCs will be scaffolded with test files and source code but their CI gate will be deferred.
