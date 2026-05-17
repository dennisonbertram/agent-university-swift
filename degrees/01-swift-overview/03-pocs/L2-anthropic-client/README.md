# L2 — anthropic-client

Typed Swift client for the Anthropic Messages API. Library-only — no executable.

## What this teaches
- Library target design in SwiftPM
- Codable for snake_case ↔ camelCase mapping (custom CodingKeys)
- Protocol-based HTTPTransport for testability (inject a mock, no network in tests)
- `AsyncThrowingStream<StreamEvent, Error>` for SSE consumption
- Idiomatic Swift error mapping (HTTP status → typed error)

## Run tests
```bash
swift test
# → all tests pass; no API key required
```

## Use it (requires `ANTHROPIC_API_KEY`)
```swift
import AnthropicClient

let client = AnthropicClient(apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!)
let resp = try await client.send(MessageRequest(
    model: "claude-sonnet-4-5-20250929",
    maxTokens: 1024,
    messages: [InputMessage(role: .user, content: .text("Say hi"))]
))
print(resp.content)
```

## Streaming
```swift
for try await event in client.stream(req) {
    if case .contentBlockDelta(_, let text) = event {
        print(text, terminator: "")
    }
}
```

## File layout
- `Sources/AnthropicClient/AnthropicClient.swift` — `send`, `stream`
- `Sources/AnthropicClient/Models.swift` — `MessageRequest`, `Message`, `ContentBlock`, `Usage`
- `Sources/AnthropicClient/StreamEvent.swift` — `StreamEvent` enum + SSE parser
- `Sources/AnthropicClient/HTTPTransport.swift` — protocol + URLSession-backed default
- `Sources/AnthropicClient/Errors.swift` — `AnthropicError`
- `Tests/AnthropicClientTests/` — 3 test files + MockHTTPTransport
