# Lesson 5 — Anthropic Messages API and SSE Streaming

[Back to index](../index.md) | Prev: [Lesson 4](lesson-04-http-transport-seam.md) | Next: [Lesson 6](lesson-06-cli-tools-with-argument-parser.md)

## Goal

After this lesson you can implement the Anthropic Messages API client — both non-streaming and SSE streaming — and parse the byte stream correctly.

## Prerequisites

[Lesson 4](lesson-04-http-transport-seam.md) — `HTTPTransport` seam.
[Lesson 3](lesson-03-typed-clients-with-codable.md) — Codable models.

## Concepts

### 5.1 Required request headers

Every request to `POST https://api.anthropic.com/v1/messages` must include:

| Header | Value |
|--------|-------|
| `x-api-key` | Your API key (from env: `ANTHROPIC_API_KEY`) |
| `anthropic-version` | `"2023-06-01"` (literal string, not a date you compute) |
| `content-type` | `"application/json"` |

Missing any header → HTTP 401 or 400.

Evidence: `before-you-build/anthropic-integration.md`; `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift:28-79`.

### 5.2 `max_tokens` is required

Unlike some LLM APIs, Anthropic requires `max_tokens` on every request. Omitting it yields:

```json
{"type":"error","error":{"type":"invalid_request_error","message":"max_tokens: field required"}}
```

Model it as a non-optional `Int` so the compiler enforces it. See [ref-anthropic-messages-api.md](../reference/ref-anthropic-messages-api.md) for the full request shape.

### 5.3 Non-streaming `send`

```swift
public func send(_ request: MessageRequest) async throws -> Message {
    let urlRequest = try buildURLRequest(for: request)
    let (data, response) = try await transport.send(urlRequest)
    let body = String(decoding: data, as: UTF8.self)
    switch response.statusCode {
    case 200:
        do { return try JSONDecoder().decode(Message.self, from: data) }
        catch { throw AnthropicError.decodeFailure(underlying: error.localizedDescription) }
    case 400: throw AnthropicError.badRequest(body: body)
    case 401: throw AnthropicError.unauthorized(body: body)
    case 429:
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
        throw AnthropicError.rateLimited(retryAfter: retryAfter, body: body)
    default: throw AnthropicError.serverError(status: response.statusCode, body: body)
    }
}
```

Evidence: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:30-46`.

### 5.4 SSE stream — the `stream: true` flag

For streaming, set `stream: true` on the request before sending:

```swift
public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
    var streamRequest = request
    streamRequest.stream = true           // must be set
    let frozenRequest = streamRequest     // snapshot for @Sendable closure

    return AsyncThrowingStream { continuation in
        let task = Task {
            do {
                let urlRequest = try self.buildURLRequest(for: frozenRequest)
                let (byteStream, response) = try await self.transport.bytes(urlRequest)
                guard response.statusCode == 200 else {
                    let body = ""
                    continuation.finish(throwing: AnthropicError.serverError(
                        status: response.statusCode, body: body))
                    return
                }
                let eventStream = SSEParser.parse(bytes: byteStream)
                for try await event in eventStream {
                    try Task.checkCancellation()
                    continuation.yield(event)
                    if case .messageStop = event { continuation.finish(); return }
                }
                continuation.finish()
            } catch { continuation.finish(throwing: error) }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

Evidence: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:51-90`; `anti-patterns/forgetting-stream-true-on-streaming-request.md`.

### 5.5 SSE line parsing

The SSE protocol delivers lines:
```
event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: message_stop
data: {"type":"message_stop"}

```

Rules:
1. Lines end with `\n`. Strip a trailing `\r` for CRLF.
2. Blank line (`\n\n`) = end of event; dispatch and reset accumulators.
3. Lines starting with `:` are comments; ignore.
4. After `event:`, strip at most ONE space. After `data:`, strip at most ONE space.
5. `event: ping` events are keep-alives; ignore them entirely.
6. The stream ends with `event: message_stop` — NOT `data: [DONE]`.

```swift
} else if trimmed.hasPrefix("data:") {
    let rest = String(trimmed.dropFirst("data:".count))
    currentData = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
}
```

**Do not** use `.trimmingCharacters(in: .whitespaces)` — that strips leading spaces that are part of the JSON payload.

Evidence: `gotchas/sse-data-space-is-one-character.md`; `patterns/sse-line-parsing.md`; `L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift:107-113`.

### 5.6 Anthropic SSE event types

| `event:` value | Meaning |
|----------------|---------|
| `message_start` | New message begin; contains input token count |
| `content_block_start` | New content block |
| `content_block_delta` | Text delta; the chunk you display |
| `content_block_stop` | Content block finished |
| `message_delta` | Stop reason and output token count |
| `message_stop` | Stream is done; close the connection |
| `ping` | Keep-alive; ignore |

Only `content_block_delta` carries displayable text. The `text` field is in `delta.text`.

### 5.7 Anthropic SSE termination

Anthropic does **NOT** use OpenAI's `data: [DONE]` convention. The stream ends with:

```
event: message_stop
data: {"type":"message_stop"}

```

After that the HTTP connection closes. A parser waiting for `[DONE]` will hang indefinitely.

Evidence: `gotchas/anthropic-sse-has-no-done-marker.md`; `01-research/06-expectation-gaps.md EG-05`.

### 5.8 Ping filtering

```swift
if currentEvent != "ping" && !currentEvent.isEmpty {
    if let event = try parseEvent(type: currentEvent, data: currentData) {
        continuation.yield(event)
    }
}
```

Evidence: `gotchas/sse-ping-events-must-be-ignored.md`; `L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift:91`.

## Walkthrough — Full SSE Parser Structure

See the annotated example: [example-l2-sseparser.md](../examples/example-l2-sseparser.md).

The canonical parser is ~100 lines in `L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift`. The key dispatch loop:

```swift
for try await byte in bytes {
    if byte == UInt8(ascii: "\n") {
        let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
        lineBuffer = []
        let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line

        if trimmed.isEmpty {
            // blank line = dispatch
            if !currentData.isEmpty,
               currentEvent != "ping",
               !currentEvent.isEmpty,
               let event = try parseEvent(type: currentEvent, data: currentData) {
                continuation.yield(event)
                if case .messageStop = event { continuation.finish(); return }
            }
            currentEvent = ""; currentData = ""
        } else if trimmed.hasPrefix(":") {
            continue   // comment line
        } else if trimmed.hasPrefix("event:") {
            let rest = String(trimmed.dropFirst("event:".count))
            currentEvent = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
        } else if trimmed.hasPrefix("data:") {
            let rest = String(trimmed.dropFirst("data:".count))
            currentData = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
        }
    } else {
        lineBuffer.append(byte)
    }
}
```

## Pitfalls

- **Forgetting `stream: true`** → Anthropic returns a single JSON message, not an SSE stream. See [ts-stream-true-flag-missing-from-request.md](../troubleshooting/ts-stream-true-flag-missing-from-request.md).
- **Using `.trimmingCharacters` on the `data:` value** → leading spaces in JSON payloads are silently dropped. See [troubleshooting/ts-sse-stream-hangs-no-done-marker.md](../troubleshooting/ts-sse-stream-hangs-no-done-marker.md).
- **Expecting `data: [DONE]`** → stream hangs. See [ts-sse-stream-hangs-no-done-marker.md](../troubleshooting/ts-sse-stream-hangs-no-done-marker.md).
- **Not filtering `ping`** → `parseEvent` throws on an unexpected payload type.

## Exercise

Read the annotated SSE parser: [example-l2-sseparser.md](../examples/example-l2-sseparser.md). Then implement `AnthropicClient.stream(_:)` end-to-end in a test target against a `MockHTTPTransport`.

## Recap

- Three required headers on every request: `x-api-key`, `anthropic-version`, `content-type`.
- `max_tokens` is required and non-optional.
- For streaming: set `stream: true` on the request (the client should also defensively set it internally).
- SSE: strip at most one space after `data:` / `event:`.
- Ignore `ping` events; finish on `message_stop`, not `[DONE]`.
