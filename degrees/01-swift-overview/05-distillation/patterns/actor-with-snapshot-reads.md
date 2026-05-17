# Pattern: actor-isolated state, snapshot reads at the moment you need to send the value across an isolation boundary

**Category**: pattern

## What
Wrap mutable conversation/session state in an `actor`. Expose a `snapshot()` method that returns an immutable copy of the state. When you need to hand the state to a `@Sendable` closure (e.g. building an outgoing request from inside an `AsyncThrowingStream` task), `await` the snapshot first, then pass the resulting value — never reach back into the actor from inside the closure to read live state.

## When to apply
- Any time you have mutable shared state for a session (chat history, request log, in-flight task registry) that is read on one isolation domain and written on another.
- When you need cancellation safety: the snapshot is captured before you start streaming, so cancelling the task does not leave the actor in an inconsistent intermediate state.

## Canonical code

```swift
import AnthropicClient

public actor ConversationActor {
    public private(set) var messages: [InputMessage] = []
    public init() {}

    public func append(role: Role, text: String) {
        messages.append(InputMessage(role: role, content: .text(text)))
    }

    public func appendOrExtend(role: Role, deltaText: String) {
        if let last = messages.last, last.role == role,
           case .text(let existing) = last.content {
            messages[messages.count - 1] = InputMessage(role: role, content: .text(existing + deltaText))
        } else {
            messages.append(InputMessage(role: role, content: .text(deltaText)))
        }
    }

    public func snapshot() -> [InputMessage] { messages }
    public func removeLast() { if !messages.isEmpty { messages.removeLast() } }
    public func count() -> Int { messages.count }
}
```

Consumer (a `Sendable` struct):

```swift
public struct ChatSession: Sendable {
    public let history: ConversationActor

    public func send(userText: String) -> AsyncThrowingStream<String, Error> {
        let history = self.history
        return AsyncThrowingStream { continuation in
            let task = Task {
                await history.append(role: .user, text: userText)
                let snapshot = await history.snapshot()            // <-- read once
                let req = MessageRequest(/* ... */, messages: snapshot, stream: true)
                // stream the request; mutate history through actor as deltas arrive
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

## Variants and trade-offs
- An actor's `snapshot()` is just `return state` — the value type copy semantics do the work.
- This pattern combines naturally with `AsyncThrowingStream` cancellation: the in-flight task references the snapshot, not live state, so cancellation cannot corrupt anything.
- `appendOrExtend` shows actor methods doing useful work (coalescing same-role messages) without exposing mutation primitives.
- For a `@MainActor`-bound view model the same shape applies, except the "actor" is the view model class itself and the snapshot is `messages.map { ... }` taken on the main actor before kicking off the streaming task — see `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:38-53` for that flavor.

## Evidence
- POC: `L3-cli-chat/Sources/ChatCore/ConversationActor.swift:4-30` — the actor.
- POC: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:27-80` — `let history = self.history` then `await history.snapshot()` inside the stream task.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:42-53` — same snapshot pattern on `@MainActor`.
- Research: `01-research/01-language-and-concurrency.md` §8 lines 222-247 — actor isolation semantics.
- See also: gotcha `gotchas/captured-let-snapshot-in-sendable-closure.md`, pattern `patterns/asyncthrowingstream-with-onTermination.md`.
