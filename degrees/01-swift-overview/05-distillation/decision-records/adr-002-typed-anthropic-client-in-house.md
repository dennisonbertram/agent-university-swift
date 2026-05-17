# ADR-002: Build a typed Anthropic client in-house (no community SDK)

**Date**: 2026-05-16

## Decision
The L2 `AnthropicClient` is built from scratch using `URLSession` + `Codable` + `AsyncThrowingStream`. The corpus does NOT depend on `fumito-ito/AnthropicSwiftSDK`, `GeorgeLyon/SwiftClaude`, or any other community Swift SDK.

## Alternatives considered
- **fumito-ito/AnthropicSwiftSDK 0.14.0** — most feature-complete community SDK; single-maintainer, 18 stars.
- **GeorgeLyon/SwiftClaude** — Swift 6 native, pre-1.0, no tagged releases, self-described "under-tested."
- **Wait for an official SDK** — Anthropic ships Python, TypeScript, Go, Java, PHP, Ruby. There is no official Swift SDK as of 2026-05.

## Why in-house
1. **No official guarantee**. Anthropic's GitHub org has zero Swift API client repositories (verified via `https://api.github.com/orgs/anthropics/repos`). Community SDKs have no parity contract with the API.
2. **Tiny surface area**. The Messages API surface needed for L2–capstone is small: one `POST /v1/messages` endpoint with two shapes (non-streaming + SSE). The whole client fits in ~250 lines plus models. Adding a dependency for this is over-engineering.
3. **Swift 6 cleanliness**. Pre-1.0 SDKs were written before Swift 6's strict concurrency landed. They tend to need `@unchecked Sendable` annotations or have not migrated yet. The in-house client is `Sendable`-clean from the start.
4. **Test isolation**. The `HTTPTransport` protocol seam (pattern `patterns/http-transport-seam.md`) lets every test in L2-L6 run without a network call. Community SDKs do not expose a comparable seam.
5. **Versioning sanity**. We pin `anthropic-version: 2023-06-01` ourselves. A community SDK might pin a different version on its own schedule.

## Trade-offs accepted
- **Maintenance burden**. When Anthropic adds a new feature (e.g. prompt caching, computer use), we update our own types. The community SDK would do this for us — but only for features the maintainer prioritises.
- **No tool-use convenience helpers**. The L2 client has `ContentBlock` shape support but no high-level tool-use orchestration. This is acceptable for the corpus; if needed, build on top.
- **Bug surface**. Every bug in our parser is ours to find. Mitigation: comprehensive test suite (L2 has 33 tests, plus regression pins).

## Evidence
- Research: `01-research/03-anthropic-api-in-swift.md` §9 lines 535-557 — community SDK assessment table and recommendation.
- Research: `01-research/06-expectation-gaps.md` EG-06 lines 127-141 — "No Official Anthropic Swift SDK Exists".
- POC: `L2-anthropic-client/Sources/AnthropicClient/` — full in-house client; Foundation only.
- POC: `L2-anthropic-client/Package.swift:1-16` — no external dependencies declared.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/` — 33 tests including SSE parser, encoding/decoding, error mapping, regressions.
