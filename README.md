# Agent University — Swift

A structured "degree" teaching autonomous LLM coding agents how to build real software in Swift.

## Audience

LLM agents (autonomous coding agents). Every artifact in this repo is optimized for an LLM reader: explicit, well-structured, copy-paste-ready.

## Scope

Full-stack Swift for autonomous coding agents:

- **Language & runtime:** Swift 6 fundamentals — types, protocols, generics, error handling.
- **Concurrency:** async/await, structured concurrency, actors, `Sendable`, `AsyncSequence` streaming.
- **Packaging:** SwiftPM (executable, library, multiplatform), `swift-testing`, `swift-argument-parser`.
- **LLM integration:** typed Anthropic Messages API client with streaming.
- **CLI:** terminal chat tool against Claude.
- **Server:** Hummingbird HTTP service exposing the LLM as a tool surface.
- **macOS desktop app:** SwiftUI chat UI using the shared LLM client.
- **iOS / iPhone app:** SwiftUI chat UI sharing code with the macOS app via a SwiftPM package.
- **Capstone:** unified multiplatform chat app + Hummingbird backend, end-to-end.

Out of scope: UIKit/AppKit, watchOS/tvOS/visionOS, Vapor, distributed actors, Embedded Swift, on-device ML.

The host machine has Swift Command Line Tools only — full Xcode must be installed before L5/L6/capstone can be build-verified. This is flagged in the readiness assessment.

## Layout

- `degrees/01-swift-overview/` — the first (and currently only) degree.
- `shared/` — cross-degree glossary, platform fundamentals, conventions.
- `docs/context/` — durable session context (intent, decisions, practices).

## Status

In progress. See `degrees/01-swift-overview/00-metadata/degree.md` for the live status.

## How to read this repo

If you are an LLM agent and want to learn Swift via this degree, start here: `degrees/01-swift-overview/06-skill-pack/index.md` (filled in Phase 11).

Until the skill pack exists, the canonical entry point is `degrees/01-swift-overview/00-metadata/degree.md`.
