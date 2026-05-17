# ADR-001: Use Hummingbird 2.x (not Vapor) for the L4 and capstone HTTP services

**Date**: 2026-05-16

## Decision
The Swift HTTP service in this corpus (L4 `tool-server` and the capstone `chat-backend`) uses Hummingbird 2.x.

## Alternatives considered
- **Vapor** — the larger, more featureful Swift web framework.
- Direct SwiftNIO usage — no framework abstraction at all.

## Why Hummingbird
1. **Swift 6 native**. Hummingbird 2.x is built for structured concurrency from the ground up: handlers are `async throws`, the framework is `Sendable`-clean, and the lifecycle is wrapped in `ServiceLifecycle` for graceful shutdown. The corpus needs all of this.
2. **Minimal surface**. The framework's mental model is `Router → middleware chain → handler closures`. Two key types (`Router`, `Application`) plus closure-based handlers. Vapor's API surface is larger (Leaf templates, Fluent ORM, Queues) and the corpus does not need any of it.
3. **Verified working**. The Hummingbird 2.23.0 probe at `/tmp/swift-research-probe/hb-test/` compiled and linked successfully (Build complete! 61.91s) with the exact patterns used in L4 and the capstone.
4. **Streaming `ResponseBody` shape works for SSE**. The `ResponseBody { writer in ... }` closure is exactly what we need for `text/event-stream` responses.

## Trade-offs accepted
- Less framework "battery" — no ORM, no template engine, no queues. Acceptable: we are proxying LLM calls, not building a CMS.
- Smaller community than Vapor. The vendor (hummingbird-project / Apple-adjacent maintainers) is active enough; the 2.x release on 2024 and rolling 2.23.0 in May 2026 confirms maintenance.
- LLM training data for Hummingbird is sparser than Vapor, AND it conflates 1.x and 2.x APIs (see gotcha `gotchas/hummingbird-1x-syntax-does-not-compile-on-2x.md`).

## Evidence
- Research: `01-research/04-hummingbird.md` §1-§12 — full Hummingbird 2.x reference; line 6 confirms `Verified with: runtime probe /tmp/swift-research-probe/hb-test/ — Build complete! (61.91s)`.
- Research: `01-research/06-expectation-gaps.md` EG-03 lines 58-77 — Hummingbird 1.x → 2.x breaking changes table.
- POC: `L4-hummingbird-tool-service/Package.swift:14-16` — `from: "2.0.0"`.
- POC: `L-capstone-multiplatform-chat/Package.swift:17` — same version pin in the capstone.
