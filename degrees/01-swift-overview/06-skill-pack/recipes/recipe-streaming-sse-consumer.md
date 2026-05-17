# Recipe — SSE Byte-Stream to Typed Event Loop

[Back to index](../index.md) | See also: [lesson-05-anthropic-messages-api-streaming.md](../lessons/lesson-05-anthropic-messages-api-streaming.md) | Pattern: `patterns/sse-line-parsing.md`

## Use this when

You have an `AsyncThrowingStream<UInt8, Error>` from an SSE source and need to parse it into typed events.

## Canonical SSE parser

```swift
struct SSEParser {
    static func parse(bytes: AsyncThrowingStream<UInt8, Error>) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var lineBuffer: [UInt8] = []
                    var currentEvent: String = ""
                    var currentData: String = ""

                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                            lineBuffer = []
                            // Strip trailing \r for CRLF
                            let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line

                            if trimmed.isEmpty {
                                // Blank line = end of event; dispatch + reset
                                if !currentData.isEmpty,
                                   currentEvent != "ping",   // ignore ping
                                   !currentEvent.isEmpty,
                                   let event = try parseEvent(type: currentEvent, data: currentData) {
                                    continuation.yield(event)
                                    if case .messageStop = event {
                                        continuation.finish(); return
                                    }
                                }
                                currentEvent = ""; currentData = ""
                            } else if trimmed.hasPrefix(":") {
                                continue                     // comment line
                            } else if trimmed.hasPrefix("event:") {
                                let rest = String(trimmed.dropFirst("event:".count))
                                // Strip at most ONE space (not all whitespace)
                                currentEvent = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
                            } else if trimmed.hasPrefix("data:") {
                                let rest = String(trimmed.dropFirst("data:".count))
                                // Strip at most ONE space
                                currentData = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func parseEvent(type: String, data: String) throws -> StreamEvent? {
        let jsonData = Data(data.utf8)
        let decoder = JSONDecoder()
        switch type {
        case "message_start":
            return .messageStart(try decoder.decode(MessageStartPayload.self, from: jsonData))
        case "content_block_delta":
            let payload = try decoder.decode(ContentBlockDeltaPayload.self, from: jsonData)
            return .contentBlockDelta(index: payload.index, textDelta: payload.delta.text)
        case "message_stop":
            return .messageStop
        default:
            return nil     // unknown events: drop silently (forward-compatible)
        }
    }
}
```

## Key rules to never break

1. Strip at most ONE space after `data:` — not all whitespace. `trimmingCharacters` is wrong.
2. Filter `ping` events before decoding.
3. Finish the stream on `message_stop` — not on `data: [DONE]`.
4. Unknown event types return `nil` and are dropped — do not throw.

## Feeding canned bytes in tests

```swift
func makeByteStream(from string: String) -> AsyncThrowingStream<UInt8, Error> {
    AsyncThrowingStream { continuation in
        Task {
            for byte in string.utf8 { continuation.yield(byte) }
            continuation.finish()
        }
    }
}

let sseInput = """
event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: message_stop
data: {"type":"message_stop"}

"""

let byteStream = makeByteStream(from: sseInput)
var events: [StreamEvent] = []
for try await event in SSEParser.parse(bytes: byteStream) {
    events.append(event)
}
// events == [.contentBlockDelta(0, "Hello"), .messageStop]
```

Evidence: `L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift:70-178`; `L2-anthropic-client/Tests/AnthropicClientTests/SSEParserTests.swift`.
