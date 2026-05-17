# Example — L2: `StreamEvent.swift` SSE Parser Walkthrough

[Back to index](../index.md) | POC: `degrees/01-swift-overview/03-pocs/L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift`

## What this example demonstrates

- Byte-by-byte SSE parser that handles CRLF, ping filtering, `message_stop` termination, and the one-space rule.
- `AsyncThrowingStream<StreamEvent, Error>` as the output type.
- `parseEvent(type:data:)` that drops unknown event types safely.

## Parser entry point

```swift
// StreamEvent.swift ~line 70
struct SSEParser {
    static func parse(bytes: AsyncThrowingStream<UInt8, Error>) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var lineBuffer: [UInt8] = []
                    var currentEvent: String = ""
                    var currentData: String = ""
```

The function takes `AsyncThrowingStream<UInt8, Error>` — not `URLSession.AsyncBytes` — so it works with both production and test byte sources.

## Main byte loop

```swift
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                            lineBuffer = []
                            let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line
```

Accumulates bytes until `\n`. Strips trailing `\r` for CRLF compatibility.

## Blank line dispatch

```swift
                            if trimmed.isEmpty {
                                // Blank line = end of event
                                if !currentData.isEmpty,
                                   currentEvent != "ping",    // ← filter ping BEFORE decode
                                   !currentEvent.isEmpty,
                                   let event = try parseEvent(type: currentEvent, data: currentData) {
                                    continuation.yield(event)
                                    if case .messageStop = event {
                                        continuation.finish()
                                        return                // ← finish on message_stop
                                    }
                                }
                                currentEvent = ""
                                currentData = ""
```

Three checks before decoding:
1. `!currentData.isEmpty` — skip events with no data
2. `currentEvent != "ping"` — silently skip keep-alives before attempting decode
3. `!currentEvent.isEmpty` — skip comment-only events

## Field parsing — the one-space rule

```swift
                            } else if trimmed.hasPrefix("event:") {
                                let rest = String(trimmed.dropFirst("event:".count))
                                currentEvent = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
                            } else if trimmed.hasPrefix("data:") {
                                let rest = String(trimmed.dropFirst("data:".count))
                                currentData = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
```

Source: `StreamEvent.swift:107-113`. Strips at most ONE space. Not `.trimmingCharacters` — that would eat spaces that are part of the JSON payload.

## `parseEvent` — drop unknowns

```swift
private static func parseEvent(type: String, data: String) throws -> StreamEvent? {
    let jsonData = Data(data.utf8)
    let decoder = JSONDecoder()
    switch type {
    case "message_start":
        return .messageStart(try decoder.decode(MessageStartPayload.self, from: jsonData))
    case "content_block_start":
        return .contentBlockStart(try decoder.decode(ContentBlockStartPayload.self, from: jsonData))
    case "content_block_delta":
        let p = try decoder.decode(ContentBlockDeltaPayload.self, from: jsonData)
        return .contentBlockDelta(index: p.index, textDelta: p.delta.text)
    case "content_block_stop":
        return .contentBlockStop(index: try decoder.decode(ContentBlockStopPayload.self, from: jsonData).index)
    case "message_delta":
        return .messageDelta(try decoder.decode(MessageDeltaPayload.self, from: jsonData))
    case "message_stop":
        return .messageStop
    default:
        return nil     // unknown types dropped silently — forward-compatible
    }
}
```

Returning `nil` for unknown types means new Anthropic event types don't break the parser.

## Test helpers

```swift
// Tests/AnthropicClientTests/SSEParserTests.swift
func makeByteStream(from string: String) -> AsyncThrowingStream<UInt8, Error> {
    AsyncThrowingStream { continuation in
        Task {
            for byte in string.utf8 { continuation.yield(byte) }
            continuation.finish()
        }
    }
}
```

Source: `L2-anthropic-client/Tests/AnthropicClientTests/SSEParserTests.swift:8-15`. Converts a fixture string to the same `AsyncThrowingStream<UInt8, Error>` the parser expects — enabling unit tests with no network.

## Key regression tests

- `filtersPingEvents` — asserts `ping` does NOT appear in the output stream.
- `leadingSpaceInJSONPayloadPreserved` — asserts `text == " world"` is preserved verbatim.
- `noSpaceFormHandled` — asserts `data:{...}` (no space) parses correctly.
- `fullSSESequence` — asserts 7 events in the output from an 8-event input (one is ping).

Source: `L2-anthropic-client/Tests/AnthropicClientTests/SSEParserTests.swift:30-238`.
