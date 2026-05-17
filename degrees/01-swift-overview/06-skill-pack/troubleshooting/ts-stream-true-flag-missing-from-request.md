# Troubleshooting — SSE Route Returns a Single JSON Block Instead of a Stream

[Back to index](../index.md)

## Symptom

A `POST /v1/messages` call that should stream returns a single JSON message object instead of SSE frames. The response body is:

```json
{"id":"msg_abc","type":"message","role":"assistant","content":[...],"stop_reason":"end_turn",...}
```

instead of:

```
event: message_start
data: {...}

event: content_block_delta
data: {...}

event: message_stop
data: {...}
```

## Diagnosis

The request did not include `"stream": true` in the JSON body. Anthropic defaults to non-streaming mode when the `stream` field is absent or `false`.

## Fix

Ensure `stream: true` is set on the request. The client should also set it defensively regardless of what the caller provides:

```swift
public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
    var streamRequest = request
    streamRequest.stream = true           // ← set it, even if caller already set it
    let frozenRequest = streamRequest     // snapshot for @Sendable closure
    // ...
}
```

The `stream` field in `MessageRequest`:

```swift
public struct MessageRequest: Codable, Sendable, Equatable {
    // ...
    public var stream: Bool?    // set to true for SSE

    enum CodingKeys: String, CodingKey {
        // ...
        case stream
    }
}
```

## Regression pin

```swift
@Test("REGRESSION-002: stream=true is set on every streaming request")
func streamFlagAlwaysTrue() async throws {
    let mock = MockLLMService()
    mock.events = [.messageStop]
    let session = ChatSession(service: mock, model: "m", maxTokens: 100)
    for try await _ in session.send(userText: "ping") {}
    let req = mock.capturedRequests[0]
    #expect(req.stream == true,
            "stream must be true; if nil/false, streaming was accidentally disabled")
}
```

Evidence: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:130-141`; `anti-patterns/forgetting-stream-true-on-streaming-request.md`.

## See also

- Lesson: [lesson-05-anthropic-messages-api-streaming.md](../lessons/lesson-05-anthropic-messages-api-streaming.md)
- Before-you-build: `before-you-build/anthropic-integration.md`
