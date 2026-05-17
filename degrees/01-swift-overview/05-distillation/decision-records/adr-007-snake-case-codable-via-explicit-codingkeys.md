# ADR-007: Snake-case ↔ camelCase via explicit `CodingKeys`, NOT `JSONDecoder.keyDecodingStrategy`

**Date**: 2026-05-16

## Decision
Anthropic request/response Codable types (`MessageRequest`, `Message`, `Usage`, SSE event payloads) declare explicit `enum CodingKeys: String, CodingKey { case maxTokens = "max_tokens" ... }`. Encoders and decoders that handle these types are plain `JSONEncoder()` / `JSONDecoder()` — no `.convertToSnakeCase` / `.convertFromSnakeCase` strategies.

## Alternatives considered
- **Strategy-based mapping**: `decoder.keyDecodingStrategy = .convertFromSnakeCase` on a "global" snake decoder used everywhere.
- **Hybrid**: explicit CodingKeys on some types, strategy on others.

## Why explicit CodingKeys win
1. **No double transform**. The strategy rewrites `max_tokens` → `maxTokens` BEFORE the CodingKey lookup. If the CodingKey raw value is `"max_tokens"`, the lookup fails. The combination silently breaks decoding (see gotcha `gotchas/snake-case-codable-double-transform.md`).
2. **Field-level correctness**. Strategies are heuristic; explicit keys are exact. Edge cases like `tool_use_id`, `input_json_delta`, `cache_creation_input_tokens` are unambiguous when declared.
3. **Forward compatibility**. New Anthropic fields can be added without worrying about the strategy mishandling them; just add the `case foo = "foo_bar"` mapping.
4. **Auditability**. A CodingKeys enum is visible in code; a global strategy is configuration on a decoder instance somewhere else.

## Trade-offs accepted
- **More boilerplate at definition time** — ~10 lines per type. Acceptable for the same reason explicit imports are: clarity over brevity.
- **You still need a snake-case encoder for other types** (e.g. `ErrorBody`, which uses default key derivation). The corpus keeps two encoders: a plain one for types with explicit CodingKeys, a snake-case one (`.convertToSnakeCase`) for types without.

## Pinning
The L4 backend has REGRESSION-001 (test (c) in RegressionTests.swift): a request body with `max_tokens` and `system` is sent through `POST /chat`; the test asserts the upstream mock received `req.maxTokens == 4096`. If someone accidentally adds `.convertFromSnakeCase` to `requestDecoder`, this fails.

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/Models.swift:126-186` — explicit `CodingKeys` on `MessageRequest`, `Usage`, `Message`.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:91-95` — explicit comment with the rationale; uses `private let requestDecoder = JSONDecoder()` (no strategy).
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/Router.swift:88-91` — same.
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/RegressionTests.swift:90-124` — REGRESSION pin.
- Research: `01-research/01-language-and-concurrency.md` §5 line 147 — "Prefer explicit `CodingKeys` for API types where correctness is critical."
- See also: gotcha `gotchas/snake-case-codable-double-transform.md`, anti-pattern `anti-patterns/convert-from-snake-case-on-explicit-codingkeys.md`.
