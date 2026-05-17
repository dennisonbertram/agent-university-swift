# Anti-pattern: `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` on a type that already declares snake_case `CodingKeys`

**Category**: anti-pattern

## Broken approach

```swift
// DO NOT do this if your Codable type has explicit CodingKeys with snake_case raw values
extension JSONDecoder {
    static let snake: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase   // ← double transform
        return d
    }()
}

private let requestDecoder = JSONDecoder.snake
let payload = try requestDecoder.decode(MessageRequest.self, from: data)
//                                       ^^^^^^^^^^^^^^
// MessageRequest has CodingKeys: case maxTokens = "max_tokens" already
```

## Why it fails
`.convertFromSnakeCase` rewrites incoming keys before the decoder looks at the CodingKeys table:
- `max_tokens` (wire) → `maxTokens` (after strategy) → looked up against CodingKey raw value `"max_tokens"` → **no match**.

Either you get a `keyNotFound` error against valid wire input, or, by coincidence of casing, decoding succeeds in tests but breaks on slight variations (e.g. `tool_use_id`). The corpus REGRESSION-001 in L4 pins this specifically because it almost went undetected.

## Right approach
Use a plain `JSONDecoder()` for types that have explicit snake_case CodingKeys. Keep two decoders if you also have types that DO need the strategy:

```swift
// MessageRequest already maps maxTokens ↔ max_tokens via its own CodingKeys
private let requestDecoder = JSONDecoder()
let payload = try requestDecoder.decode(MessageRequest.self, from: data)

// If you also decode types without explicit CodingKeys (like ErrorBody), keep a
// separately-configured decoder that uses the strategy.
extension JSONDecoder {
    static let snake: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
```

Likewise on the encoder side — types with explicit `CodingKeys` rawValues should NOT additionally go through `.convertToSnakeCase`.

## Evidence
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:91-95` — explicit comment: `"MessageRequest already has explicit CodingKeys with snake_case strings ... convertFromSnakeCase would double-transform and break the explicit mappings."`
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/RegressionTests.swift:90-124` — `snakeCaseKeysDecodeCorrectly`. The test comment line 86-89 calls out: "If someone accidentally switches to convertFromSnakeCase this test catches the breakage."
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/Router.swift:88-91` — same comment, same plain `requestDecoder`.
- POC: `L2-anthropic-client/Sources/AnthropicClient/Models.swift:126-186` — explicit `CodingKeys` with `case maxTokens = "max_tokens"`, `case inputTokens = "input_tokens"`, etc.
- Research: `01-research/01-language-and-concurrency.md` §5 line 147 — "Prefer explicit `CodingKeys` for API types where correctness is critical."
- See also: gotcha `gotchas/snake-case-codable-double-transform.md`, ADR `decision-records/adr-007-snake-case-codable-via-explicit-codingkeys.md`.
