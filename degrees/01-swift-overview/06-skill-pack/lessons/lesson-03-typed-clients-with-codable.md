# Lesson 3 — Typed Clients with Codable

[Back to index](../index.md) | Prev: [Lesson 2](lesson-02-swift6-concurrency.md) | Next: [Lesson 4](lesson-04-http-transport-seam.md)

## Goal

After this lesson you can model API request/response shapes with `Codable`, handle the snake_case ↔ camelCase mapping correctly, and write JSON round-trip tests.

## Prerequisites

[Lesson 1](lesson-01-swift-toolchain-and-swiftpm.md) — SwiftPM and swift-testing.

## Concepts

### 3.1 Why explicit `CodingKeys` instead of `.convertFromSnakeCase`

The Anthropic Messages API uses `snake_case` field names (`max_tokens`, `stop_reason`, etc.). Swift property names are `camelCase`. There are two ways to handle this:

**Option A — `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`**: the decoder rewrites incoming JSON keys before matching. Simple, but dangerous when combined with explicit `CodingKeys`.

**Option B — explicit `CodingKeys` enum with snake_case raw values**: the struct declares the exact wire format. No decoder strategy needed.

The corpus uses **Option B** for all Anthropic types. Reason: if a type already declares explicit `CodingKeys` with snake_case raw values, adding `.convertFromSnakeCase` causes a double-transformation that silently breaks decoding:

```
HTTP 400: decode failed: Key not found: "maxTokens"
```

Evidence: `gotchas/snake-case-codable-double-transform.md`; `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:91-95`.

### 3.2 Canonical request model

```swift
public struct MessageRequest: Codable, Sendable, Equatable {
    public var model: String
    public var maxTokens: Int                   // required, non-optional
    public var messages: [InputMessage]
    public var system: String?
    public var temperature: Double?
    public var stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"           // snake_case raw value
        case messages, system, temperature, stream
    }
}

public struct InputMessage: Codable, Sendable, Equatable {
    public var role: Role
    public var content: Content
}

public enum Role: String, Codable, Sendable, Equatable {
    case user, assistant
}
```

`maxTokens` is a non-optional `Int`. The Anthropic API rejects requests that omit it with HTTP 400. Modelling it as non-optional pushes the requirement to every callsite. Evidence: `gotchas/max-tokens-required-on-every-anthropic-request.md`; `L2-anthropic-client/Sources/AnthropicClient/Models.swift:109-117`.

### 3.3 Handling the `content` dual shape

Anthropic's `content` field in responses can be either a `String` or an array of content blocks. Model with a custom `Codable` enum:

```swift
public enum Content: Codable, Sendable, Equatable {
    case text(String)
    case blocks([ContentBlock])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .blocks(try container.decode([ContentBlock].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .blocks(let b): try container.encode(b)
        }
    }
}
```

Evidence: `L2-anthropic-client/Sources/AnthropicClient/Models.swift`.

### 3.4 Typed error enum

Define errors as a typed enum rather than raw `String` or `Error`:

```swift
public enum AnthropicError: Error, Equatable, Sendable {
    case unauthorized(body: String)
    case rateLimited(retryAfter: String?, body: String)
    case badRequest(body: String)
    case serverError(status: Int, body: String)
    case decodeFailure(underlying: String)
    case streamProtocol(message: String)
}
```

Map HTTP status codes to these cases in the client. This lets callers `switch` on `AnthropicError` without string parsing.

Evidence: `L2-anthropic-client/Sources/AnthropicClient/AnthropicError.swift`; `patterns/typed-error-enum-with-bodies.md`.

### 3.5 JSON round-trip testing

Test that `encode → decode → encode` produces the same JSON, and that explicit `CodingKeys` values round-trip correctly:

```swift
@Test("MessageRequest round-trips through JSON with correct snake_case keys")
func messageRequestRoundTrip() throws {
    let req = MessageRequest(
        model: "claude-sonnet-4-5-20250929",
        maxTokens: 512,
        messages: [InputMessage(role: .user, content: .text("hi"))],
        system: nil,
        temperature: nil,
        stream: true
    )
    let data = try JSONEncoder().encode(req)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(json["max_tokens"] as? Int == 512)      // snake_case on the wire
    #expect(json["model"] as? String == "claude-sonnet-4-5-20250929")
    #expect(json["stream"] as? Bool == true)
}
```

Evidence: `L4-hummingbird-tool-service/Tests/ToolServiceTests/RegressionTests.swift:90-124`.

## Walkthrough — Decoding a Response

Given this Anthropic response body:

```json
{
  "id": "msg_abc",
  "type": "message",
  "role": "assistant",
  "model": "claude-sonnet-4-5-20250929",
  "content": [{"type": "text", "text": "Hello!"}],
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {"input_tokens": 5, "output_tokens": 3}
}
```

Decode with a **plain** `JSONDecoder()` (no strategy):

```swift
let message = try JSONDecoder().decode(Message.self, from: responseData)
```

The `Message.stopReason` property has `CodingKey` value `"stop_reason"`. The plain decoder matches it correctly. Adding `.convertFromSnakeCase` would transform `"stop_reason"` → `"stopReason"` before matching the `CodingKeys`, which works coincidentally — but it also transforms `"max_tokens"` → `"maxTokens"` before looking up the `CodingKey` that has raw value `"max_tokens"`, which fails.

Rule: use a plain `JSONDecoder()` for types with explicit snake_case `CodingKeys`. Use `.convertFromSnakeCase` only for types whose `CodingKey` names are camelCase identifiers.

## Pitfalls

- **Using `.convertFromSnakeCase` on top of explicit `CodingKeys`** → decoding silently breaks. See [ts-keynotfound-during-codable-decode.md](../troubleshooting/ts-keynotfound-during-codable-decode.md).
- **Making `maxTokens` optional** → Anthropic returns HTTP 400 at runtime, not a compile error.
- **Not conforming models to `Sendable`** → the compiler rejects them when passed across actor boundaries.
- **Not conforming to `Equatable`** → you cannot `#expect(request == expected)` in tests.

## Exercise

Complete [lab-02-typed-codable-roundtrip.md](../labs/lab-02-typed-codable-roundtrip.md): write a `User` Codable with snake_case keys and a round-trip test.

## Recap

- Use explicit `CodingKeys` with snake_case raw values for Anthropic API types.
- Use a plain `JSONDecoder()` for those types — no `.convertFromSnakeCase`.
- `maxTokens` is required and non-optional.
- Model errors as a typed enum with associated values for HTTP body.
- Test JSON encoding/decoding with specific key assertions, not just equality.
