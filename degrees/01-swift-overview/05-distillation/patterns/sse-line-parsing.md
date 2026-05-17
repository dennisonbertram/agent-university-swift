# Pattern: SSE byte-stream → typed event stream with line buffer + blank-line dispatch

**Category**: pattern

## What
Consume the upstream `AsyncThrowingStream<UInt8, Error>` byte-by-byte; buffer bytes until `\n`; strip an optional trailing `\r` for CRLF; on blank lines, dispatch the accumulated `event:` / `data:` pair through a `parseEvent(type:data:)` helper that returns a typed `StreamEvent`. Filter `ping` and ignore comment lines (`:`-prefix). Finish the output stream when a `message_stop` event arrives.

## When to apply
- Parsing any SSE source (Anthropic, OpenAI, custom proxy backends). The exact event names and JSON payload shapes differ, but the line-buffer + blank-line-dispatch shape is identical.

## Canonical code

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
                            // Strip trailing \r for CRLF line endings
                            let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line

                            if trimmed.isEmpty {
                                // Blank line = end of event; dispatch + reset
                                if !currentData.isEmpty,
                                   currentEvent != "ping",
                                   !currentEvent.isEmpty,
                                   let event = try parseEvent(type: currentEvent, data: currentData) {
                                    continuation.yield(event)
                                    if case .messageStop = event {
                                        continuation.finish()
                                        return
                                    }
                                }
                                currentEvent = ""
                                currentData = ""
                            } else if trimmed.hasPrefix(":") {
                                // Comment line — ignore
                                continue
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
                    // Flush any trailing partial line at EOF (omitted for brevity)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

The `parseEvent(type:data:)` helper switches on the event name and JSON-decodes the data field:

```swift
private static func parseEvent(type: String, data: String) throws -> StreamEvent? {
    let jsonData = Data(data.utf8)
    let decoder = JSONDecoder()
    switch type {
    case "message_start":         /* decode + return .messageStart(...) */
    case "content_block_delta":   /* decode + return .contentBlockDelta(...) */
    case "message_stop":          return .messageStop
    default:                       return nil       // unknown events: drop
    }
}
```

## Variants and trade-offs
- **Why byte-by-byte not `URLSession.bytes.lines`?** Tests need to feed canned data into the parser via `AsyncThrowingStream<UInt8, Error>` (see `gotchas/urlsession-asyncbytes-has-no-public-init.md`). Parsing at the byte level lets the same parser handle production bytes and test bytes.
- Strip at most ONE leading space after the colon (see `gotchas/sse-data-space-is-one-character.md`). The corpus pins this with three regression tests.
- Unknown event types return `nil` and are silently dropped, not errored. This makes the parser forward-compatible with new event types.
- For simpler downstream protocols where you control both ends (e.g. the capstone backend re-emits `data: <text>\n\n` and `event: done\ndata: [DONE]\n\n`), `URLSession.bytes(for:).lines` is acceptable — see `L-capstone-multiplatform-chat/Sources/ChatCore/BackendLLMService.swift:53-67`.

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift:70-178` — the full canonical parser.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/SSEParserTests.swift:30-238` — 7 tests covering message_start, content_block_delta, ping filter, blank-line separation, comment lines, full sequence, leading-space preservation.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/BackendLLMService.swift:53-67` — simpler `.lines` consumer for the downstream simplified protocol.
- Research: `01-research/03-anthropic-api-in-swift.md` §5 lines 113-181 — SSE protocol reference.
- See also: gotcha `gotchas/sse-data-space-is-one-character.md`, `gotchas/sse-ping-events-must-be-ignored.md`, `gotchas/anthropic-sse-has-no-done-marker.md`.
