# `max_tokens` is required on every Anthropic Messages request

**Category**: gotcha

## What
Unlike some LLM APIs where `max_tokens` is optional, Anthropic's Messages API rejects requests that omit it with HTTP 400.

## Symptom
HTTP 400 from `POST /v1/messages` with body shape:
```json
{"type":"error","error":{"type":"invalid_request_error","message":"max_tokens: field required"}}
```

## Cause
Anthropic chooses to make output bounds explicit — no implicit upper bound. The field is documented as required (`✅`) in the official spec.

## Fix
Model `maxTokens` as a non-optional `Int` in the Swift struct so the type system enforces it at every callsite:

```swift
public struct MessageRequest: Codable, Sendable, Equatable {
    public var model: String
    public var maxTokens: Int               // non-optional
    public var messages: [InputMessage]
    public var system: String?
    public var temperature: Double?
    public var stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages, system, temperature, stream
    }
}
```

## Evidence
- Research: `01-research/03-anthropic-api-in-swift.md` §2 lines 44-55 — `max_tokens` row marked `✅ Required`.
- Research: `01-research/03-anthropic-api-in-swift.md` §10 FM-7 lines 611-613 — "Unlike some LLM APIs, `max_tokens` is required in every request."
- Research: `01-research/06-expectation-gaps.md` EG-12 lines 230-238.
- POC: `L2-anthropic-client/Sources/AnthropicClient/Models.swift:109-117` — `maxTokens: Int` (no optional).
