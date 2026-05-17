# Example — L3: `ChatSession.send` with Rollback Logic

[Back to index](../index.md) | POC: `degrees/01-swift-overview/03-pocs/L3-cli-chat/Sources/ChatCore/ChatSession.swift`

## What this example demonstrates

- The `AsyncThrowingStream` + actor-snapshot pattern in a real streaming session.
- Three-branch error handling: cancel, pre-delta error, post-delta error.
- `LLMService` protocol seam keeping `ChatSession` testable.

## `ChatSession` struct

```swift
// ChatSession.swift ~line 1
public struct ChatSession: Sendable {
    public let history: ConversationActor
    public let service: any LLMService
    public let model: String
    public let maxTokens: Int
    public let system: String?

    public init(service: any LLMService,
                model: String = "claude-sonnet-4-5-20250929",
                maxTokens: Int = 1024,
                system: String? = nil) {
        self.history = ConversationActor()
        self.service = service
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
    }
}
```

`Sendable` struct — not an actor. The mutable state (conversation history) lives in the `ConversationActor` field.

## `send(userText:)` — the core method

```swift
// ChatSession.swift ~line 27
public func send(userText: String) -> AsyncThrowingStream<String, Error> {
    // ─── Capture let snapshots for the @Sendable closure ─────────────────────
    let history = self.history
    let service = self.service
    let model = self.model
    let maxTokens = self.maxTokens
    let system = self.system

    return AsyncThrowingStream { continuation in
        let task = Task {
            // ─── Step 1: record the user message ─────────────────────────────
            await history.append(role: .user, text: userText)

            // ─── Step 2: snapshot before building the request ─────────────────
            let snapshot = await history.snapshot()   // immutable [InputMessage]
            let req = MessageRequest(model: model, maxTokens: maxTokens,
                                     messages: snapshot, system: system,
                                     temperature: nil, stream: true)

            // ─── Step 3: track whether assistant output started ───────────────
            var assistantStarted = false

            do {
                for try await event in service.stream(req) {
                    try Task.checkCancellation()   // honour cancellation requests

                    switch event {
                    case .contentBlockDelta(_, let text):
                        if !assistantStarted {
                            await history.append(role: .assistant, text: "")
                            assistantStarted = true
                        }
                        await history.appendOrExtend(role: .assistant, deltaText: text)
                        continuation.yield(text)

                    case .messageStop:
                        continuation.finish()
                        return

                    default: break
                    }
                }
                continuation.finish()
            } catch is CancellationError {
                // ─── Branch A: user cancelled ────────────────────────────────
                // Keep whatever was accumulated. This is deliberate: the user
                // has already seen the partial output; removing it is surprising.
                continuation.finish()
            } catch {
                // ─── Branch B: hard error ─────────────────────────────────────
                // Roll back user message ONLY if no assistant output arrived.
                // If the assistant started, keep the partial response visible.
                if !assistantStarted { await history.removeLast() }
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }  // propagate cancellation
    }
}
```

Source: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:27-80`.

## Key design decisions

1. **Snapshot before stream**: `await history.snapshot()` is called once before the stream starts. The stream closure only reads the immutable snapshot — no actor hops mid-stream to read history.

2. **`assistantStarted` flag**: tracks whether at least one delta arrived before an error. This makes rollback semantics precise.

3. **`continuation.onTermination`**: ensures the producer `Task` is cancelled when the consumer stops reading (e.g. Ctrl-C, view disappears).

4. **`try Task.checkCancellation()`**: inside the event loop, between suspension points, so cancellation is observed promptly.

## Behavioural tests that pin this

From `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift`:
- `BT-003: happyPath` — three deltas + messageStop → consumer gets 3 chunks.
- `BT-004: errorBeforeDeltaRollsBackUser` — error before any delta → `history.count == 0`.
- `BT-005: errorAfterOneDeltaKeepsPartial` — error after one delta → `history.count == 2`.
- `BT-006: cancellationKeepsPartial` — CancellationError → partial state retained.
