# Troubleshooting — SSE Stream Hangs / No `[DONE]` Marker

[Back to index](../index.md)

## Symptom

The SSE consumer loops forever. The stream never terminates. Or:

```
decodeFailure: The data couldn't be read because it isn't in the correct format.
```

Thrown mid-stream after previously working.

## Diagnosis

**Cause 1 — Parser waiting for `data: [DONE]`:**
Your parser was written for OpenAI's convention. Anthropic ends the stream with `event: message_stop` and then closes the HTTP connection. There is no `data: [DONE]`.

**Cause 2 — `ping` events decoded as structured events:**
Anthropic emits `event: ping` / `data: {"type":"ping"}` periodically. If your `parseEvent` function tries to decode these, it throws `decodeFailure` because `ping` does not match any of your typed event shapes.

**Cause 3 — Leading space in `data:` value stripped incorrectly:**
If you use `.trimmingCharacters(in: .whitespaces)` on the value after `data:`, you strip leading spaces that are part of the JSON payload, corrupting the JSON and causing a decode failure.

## Fixes

**Fix 1 — Terminate on `message_stop`:**

```swift
case "message_stop":
    continuation.yield(.messageStop)
    continuation.finish()
    return
```

**Fix 2 — Filter `ping` before decoding:**

```swift
if !currentData.isEmpty,
   currentEvent != "ping",    // ← ignore ping
   !currentEvent.isEmpty {
    // decode and yield
}
```

**Fix 3 — Strip at most ONE space:**

```swift
} else if trimmed.hasPrefix("data:") {
    let rest = String(trimmed.dropFirst("data:".count))
    currentData = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
    // NOT: .trimmingCharacters(in: .whitespaces)
}
```

## See also

- Distillation: `gotchas/anthropic-sse-has-no-done-marker.md`, `gotchas/sse-ping-events-must-be-ignored.md`, `gotchas/sse-data-space-is-one-character.md`
- Lesson: [lesson-05-anthropic-messages-api-streaming.md](../lessons/lesson-05-anthropic-messages-api-streaming.md)
- Recipe: [recipe-streaming-sse-consumer.md](../recipes/recipe-streaming-sse-consumer.md)
