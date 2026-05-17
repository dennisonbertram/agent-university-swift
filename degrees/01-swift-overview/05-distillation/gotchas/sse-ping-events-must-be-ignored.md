# Anthropic SSE streams interleave `ping` events that must be ignored, not decoded

**Category**: gotcha

## What
Anthropic's SSE stream emits `event: ping` / `data: {"type":"ping"}` events periodically to keep the connection alive. A naive parser that tries to decode every `data:` line against `StreamEvent` will throw `decodeFailure` mid-stream the first time a ping arrives.

## Symptom
The stream works in tests against your own happy-path fixture but throws `decodeFailure` (or yields an unexpected event) when run against the live API — typically after 10–30 seconds of streaming output.

## Cause
`ping` events do not match any structural `message_start`, `content_block_delta`, etc. shapes the typed decoder expects. They are framing-level keep-alives.

## Fix
Filter on the `event:` line before decoding:

```swift
if !currentData.isEmpty {
    if currentEvent != "ping" && !currentEvent.isEmpty {
        if let event = try parseEvent(type: currentEvent, data: currentData) {
            continuation.yield(event)
            if case .messageStop = event { continuation.finish(); return }
        }
    }
}
currentEvent = ""
currentData = ""
```

Equivalent shortcut earlier in the loop is also fine: `if eventType == "ping" { continue }`.

## Evidence
- Research: `01-research/03-anthropic-api-in-swift.md` §5 lines 156-170 — describes ping events and the `if eventType == "ping" { continue }` idiom.
- Research: `01-research/06-expectation-gaps.md` EG-13 lines 241-258 — "SSE ping Events Must Be Handled".
- POC: `L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift:91` — `if currentEvent != "ping" && !currentEvent.isEmpty {`.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/SSEParserTests.swift:75-103` — `filtersPingEvents` test pins that `ping` does NOT appear in the output stream.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/SSEParserTests.swift:153-215` — `fullSSESequence` test expects 7 events, not 8, because ping is filtered.
