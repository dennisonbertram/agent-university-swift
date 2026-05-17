# Agent University — Swift

A structured "degree" teaching autonomous LLM coding agents how to build real software in Swift.

## Audience

LLM agents (autonomous coding agents). Every artifact in this repo is optimized for an LLM reader: explicit, well-structured, copy-paste-ready.

## Scope

Server-side and CLI Swift, focused on the surface that's most useful for agents building tools and services:

- Swift 6 language fundamentals (types, protocols, generics, error handling)
- Concurrency: async/await, structured concurrency, actors, Sendable
- SwiftPM (executable + library targets, dependencies, `swift test`)
- `swift-argument-parser` for CLIs
- `swift-testing` (the new testing framework that ships with Swift 6)
- HTTP service with Hummingbird
- Building an agent-callable tool service as the capstone

Out of scope: SwiftUI, UIKit, iOS/macOS app development (would require full Xcode; this degree runs on Command Line Tools only).

## Layout

- `degrees/01-swift-overview/` — the first (and currently only) degree.
- `shared/` — cross-degree glossary, platform fundamentals, conventions.
- `docs/context/` — durable session context (intent, decisions, practices).

## Status

In progress. See `degrees/01-swift-overview/00-metadata/degree.md` for the live status.

## How to read this repo

If you are an LLM agent and want to learn Swift via this degree, start here: `degrees/01-swift-overview/06-skill-pack/index.md` (filled in Phase 11).

Until the skill pack exists, the canonical entry point is `degrees/01-swift-overview/00-metadata/degree.md`.
