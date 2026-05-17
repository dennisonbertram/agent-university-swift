# Anti-pattern: forgetting `stream: true` on a `MessageRequest` sent to the streaming endpoint

**Category**: anti-pattern

## Broken approach
Calling `client.stream(_:)` with a request whose `stream` property is `nil` (the default) or `false`:

```swift
let req = MessageRequest(
    model: "claude-sonnet-4-5-20250929",
    maxTokens: 1024,
    messages: [InputMessage(role: .user, content: .text("hi"))],
    system: nil,
    temperature: nil,
    stream: nil                     // ← forgot to set true
)
for try await event in client.stream(req) { /* ... */ }
```

## Why it fails
- The Anthropic API treats `stream` as a boolean opt-in. Without `stream: true`, the response is non-SSE and the body is a single JSON Message — SSE parsing fails on the first non-event line.
- Tests pass when the mock service does not check the `stream` field, then production breaks the first time a real call hits Anthropic.
- The wire format and HTTP content type both change based on this single boolean. Silent omission is one of the easiest fields to forget.

## Right approach
The `stream(_:)` method should set the flag itself; callers should not have to. The L2 client does exactly this — it accepts any `MessageRequest`, flips `stream = true` internally, then freezes the value for the Sendable closure:

```swift
public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
    var streamRequest = request
    streamRequest.stream = true
    let frozenRequest = streamRequest

    return AsyncThrowingStream { continuation in
        Task {
            let urlRequest = try self.buildURLRequest(for: frozenRequest)
            // ...
        }
    }
}
```

Callers (`ChatSession`, `ChatViewModel`) can also set `stream: true` explicitly at the construction site as a belt-and-braces practice:

```swift
let request = MessageRequest(
    model: model,
    maxTokens: maxTokens,
    messages: snapshot,
    system: system,
    temperature: nil,
    stream: true            // ← explicit
)
```

L3 pins this with REGRESSION-002 — every send of a streaming session must produce a `MessageRequest` where `stream == true`. If the flag is dropped (either by a refactor in `ChatSession.send` or by `AnthropicClient.stream` no longer overriding), the test fails.

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:51-55` — `var streamRequest = request; streamRequest.stream = true; let frozenRequest = streamRequest`.
- POC: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:38-45` — caller also sets `stream: true` explicitly.
- POC: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:124-141` — REGRESSION-002 pins it: `#expect(req.stream == true, "stream must be true; if nil/false, streaming was accidentally disabled")`.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:45-52` — `stream: true` in the view model.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/ChatViewModel.swift:45-53` — same.
- Research: `01-research/03-anthropic-api-in-swift.md` §2 line 51 — `stream` field is `boolean, optional, "true for SSE streaming"`.
