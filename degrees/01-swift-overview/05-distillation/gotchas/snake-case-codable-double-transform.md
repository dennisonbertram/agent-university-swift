# Do NOT use `keyDecodingStrategy = .convertFromSnakeCase` on Codable types that already declare snake_case CodingKeys

**Category**: gotcha

## What
`MessageRequest` (and other Anthropic request types in this corpus) declares explicit `CodingKeys` with snake_case raw values: `case maxTokens = "max_tokens"`. If a downstream decoder configures `keyDecodingStrategy = .convertFromSnakeCase`, the decoder applies BOTH transformations and either fails silently or rejects valid inputs.

## Symptom
- HTTP 400 from `POST /chat` with `max_tokens` correctly in the body — `decode failed: Key not found: "maxTokens"`.
- Or worse, tests pass with hand-rolled fixtures (which happen to match the camelCase result) and break against real upstream payloads.

## Cause
`.convertFromSnakeCase` rewrites incoming keys: `max_tokens` → `maxTokens`. Then the decoder looks for `maxTokens` in the struct's CodingKeys, where the struct has declared `case maxTokens = "max_tokens"`. The strategy and the explicit key are both attempting the same mapping; either the result is non-matching or you get a fragile coincidence.

## Fix
When a type already declares snake_case `CodingKeys` raw values, use a **plain** `JSONDecoder()`. Use `.convertFromSnakeCase` only for types whose CodingKeys use the default camelCase identifiers.

```swift
// MessageRequest already has explicit snake_case CodingKeys.
private let requestDecoder = JSONDecoder()   // no strategy

// Decoded straight from the wire body.
let payload = try requestDecoder.decode(MessageRequest.self, from: data)
```

If you mix both styles (e.g. an `ErrorBody` struct without explicit keys plus `MessageRequest` with them), keep two decoders: one with the strategy, one without.

## Evidence
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:91-95` — explicit comment: `"MessageRequest already has explicit CodingKeys with snake_case strings (e.g. max_tokens = \"max_tokens\"), so a plain JSONDecoder is all that is needed — convertFromSnakeCase would double-transform and break the explicit mappings."`
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/RegressionTests.swift:90-124` — `snakeCaseKeysDecodeCorrectly` is the regression pin (test (c)).
- POC: `L2-anthropic-client/Sources/AnthropicClient/Models.swift:126-133` — `MessageRequest` CodingKeys with `case maxTokens = "max_tokens"`.
- Research: `01-research/01-language-and-concurrency.md` §5 line 147 — "Prefer explicit `CodingKeys` for API types where correctness is critical."
- See also: anti-pattern `anti-patterns/convert-from-snake-case-on-explicit-codingkeys.md`, ADR `decision-records/adr-007-snake-case-codable-via-explicit-codingkeys.md`.
