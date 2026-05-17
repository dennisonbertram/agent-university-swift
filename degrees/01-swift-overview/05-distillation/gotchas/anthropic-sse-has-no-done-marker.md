# Anthropic SSE streams end with `event: message_stop`, NOT `data: [DONE]`

**Category**: gotcha

## What
Parsers that recognise OpenAI's `data: [DONE]` terminator do not terminate against Anthropic. Anthropic's Messages API streaming ends with `event: message_stop` / `data: {"type":"message_stop"}` and then closes the HTTP connection.

## Symptom
Either:
1. The client hangs waiting for `[DONE]` that never arrives.
2. The client tries to JSON-decode `"[DONE]"` as a structured event payload and throws.
3. The terminator is missed and the consumer loops forever on EOF logic.

## Cause
Different vendors picked different SSE termination conventions. OpenAI: `data: [DONE]`. Anthropic: `event: message_stop`. LLM training data conflates them.

## Fix
Match on `event: message_stop` and finish the stream:

```swift
case "message_stop":
    return .messageStop  // emit event; caller finishes the AsyncThrowingStream
```

Caller:
```swift
for try await event in service.stream(req) {
    switch event {
    case .messageStop:
        continuation.finish()
        return
    case .contentBlockDelta(_, let text):
        continuation.yield(text)
    default: break
    }
}
```

If you are building a downstream service that re-emits a simplified SSE protocol to its own clients (e.g. browsers), it is reasonable to emit your own `[DONE]` sentinel — but that is a deliberate translation, not what Anthropic itself sends. The capstone backend does exactly that: it emits `event: done\ndata: [DONE]\n\n` on its own `/chat/stream` endpoint as a downstream convention.

## Evidence
- Research: `01-research/03-anthropic-api-in-swift.md` §5 lines 173-181 — explicit: "Anthropic does **NOT** use `data: [DONE]`".
- Research: `01-research/06-expectation-gaps.md` EG-05 lines 101-123 — "Anthropic SSE Stream Does NOT End with data: [DONE]".
- POC: `L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift:170-172` — `case "message_stop": return .messageStop`.
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:78-83` — `if case .messageStop = event { continuation.finish(); return }`.
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/Router.swift:202-207` — downstream re-emits its own `event: done\ndata: [DONE]\n\n` to clients (deliberate convention, not upstream behaviour).
