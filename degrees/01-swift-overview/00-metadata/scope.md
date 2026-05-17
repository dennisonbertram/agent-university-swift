# Scope — Swift Overview

## In scope

- Swift 6.1.2 language: value/reference types, protocols + generics + associated types, error handling, optionals, result builders, macros (overview only), Codable.
- Swift concurrency model: async/await, structured concurrency, `TaskGroup`, actors, `Sendable`, cancellation.
- SwiftPM: package layout, executable + library targets, dependencies, `swift build` / `swift run` / `swift test`, `Package.swift` manifest.
- `swift-testing` (the new Swift 6 testing framework).
- `swift-argument-parser`: CLIs with subcommands, validation, structured I/O.
- `Foundation`: JSON Codable, file system, `URLSession` basics.
- Hummingbird 2.x: routing, middleware, async handlers, structured logging.
- Building an agent-callable tool service (HTTP endpoints returning structured JSON tool results).

## Out of scope

- SwiftUI, UIKit, AppKit, iOS/macOS app shells, watchOS, tvOS, visionOS.
- Xcode project / workspace files.
- Vapor (Hummingbird chosen instead).
- Distributed actors clustering.
- Embedded Swift.
- Swift-on-Linux specifics beyond "it works" (target is macOS).
- Swift Package Registry mechanics beyond basic dependency declaration.
