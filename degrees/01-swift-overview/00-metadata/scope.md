# Scope — Swift Overview

## In scope

### Language & runtime
- Swift 6.1.2 language: value/reference types, protocols + generics + associated types, error handling, optionals, result builders, macros (overview only), Codable.
- Swift concurrency: async/await, structured concurrency, `TaskGroup`, actors, `Sendable`, cancellation, `AsyncSequence` / `AsyncThrowingStream` for streaming.

### Packaging & tooling
- SwiftPM: executable + library + multiplatform targets, dependencies, `swift build` / `swift run` / `swift test`, `Package.swift` manifest, platform conditionals.
- `swift-testing` (the Swift 6 testing framework).
- `swift-argument-parser`: CLIs with subcommands.

### LLM integration (NEW)
- Typed Anthropic API client in Swift — request/response Codable types, message format, system prompts, tool use, streaming via Server-Sent Events.
- Auth handling (API key via env), retry semantics, error surfaces.
- Streaming output via `AsyncThrowingStream<MessageDelta, Error>`.

### Server-side
- Hummingbird 2.x: routing, middleware, async handlers, structured logging.
- HTTP service exposing the LLM client as a tool surface (proxy / agent backend).

### macOS frontend (NEW)
- SwiftUI for macOS: app lifecycle (`@main`, `App`, `WindowGroup`), state (`@State`, `@Observable`), composition, list views, text input.
- Calling the shared LLM client library from a SwiftUI view; rendering streaming responses live.

### iOS / iPhone frontend (NEW)
- SwiftUI for iOS: same primitives as macOS plus iOS-specific concerns (safe area, keyboard avoidance, `NavigationStack`).
- Multiplatform SwiftPM package structure: how to share the LLM client + view models between macOS and iOS targets.

## Out of scope

- UIKit, AppKit (we use SwiftUI exclusively).
- watchOS, tvOS, visionOS.
- Vapor (Hummingbird chosen).
- Distributed actors clustering.
- Embedded Swift.
- App Store submission, code signing, provisioning profiles.
- Push notifications, background modes, HealthKit, ARKit, and other domain-specific Apple frameworks.
- On-device ML / CoreML / MLX (LLM is server-side via Anthropic API).
