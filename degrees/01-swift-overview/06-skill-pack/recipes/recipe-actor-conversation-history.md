# Recipe — `ConversationActor` with Snapshot Reads

[Back to index](../index.md) | See also: [lesson-06-cli-tools-with-argument-parser.md](../lessons/lesson-06-cli-tools-with-argument-parser.md) | Pattern: `patterns/actor-with-snapshot-reads.md`

## Use this when

You need mutable conversation history that accumulates across turns and can be safely read from a `@Sendable` closure.

## The actor

```swift
import AnthropicClient   // for InputMessage, Role

public actor ConversationActor {
    public private(set) var messages: [InputMessage] = []

    public init() {}

    public func append(role: Role, text: String) {
        messages.append(InputMessage(role: role, content: .text(text)))
    }

    /// Coalesces consecutive same-role deltas — avoids a new message per token.
    public func appendOrExtend(role: Role, deltaText: String) {
        if let last = messages.last, last.role == role,
           case .text(let existing) = last.content {
            messages[messages.count - 1] = InputMessage(role: role,
                                                         content: .text(existing + deltaText))
        } else {
            messages.append(InputMessage(role: role, content: .text(deltaText)))
        }
    }

    /// Returns an immutable copy — safe to pass into a @Sendable closure.
    public func snapshot() -> [InputMessage] { messages }

    public func removeLast() { if !messages.isEmpty { messages.removeLast() } }
    public func count() -> Int { messages.count }
}
```

Evidence: `L3-cli-chat/Sources/ChatCore/ConversationActor.swift:4-30`.

## Usage pattern — snapshot before the stream closure

```swift
public struct ChatSession: Sendable {
    public let history: ConversationActor

    public func send(userText: String) -> AsyncThrowingStream<String, Error> {
        let history = self.history         // let snapshot for @Sendable closure

        return AsyncThrowingStream { continuation in
            let task = Task {
                await history.append(role: .user, text: userText)
                let snapshot = await history.snapshot()   // <-- read once, outside the loop
                let req = MessageRequest(/* ... */, messages: snapshot, stream: true)

                // The stream loop can now append deltas without re-reading the actor mid-flight
                for try await event in service.stream(req) {
                    if case .contentBlockDelta(_, let text) = event {
                        await history.appendOrExtend(role: .assistant, deltaText: text)
                        continuation.yield(text)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

## Why snapshot?

If you read `history.messages` directly inside the stream loop (via `await history.messages`), every delta causes an actor hop. Worse, if the task is cancelled between hops, the actor may be in an inconsistent intermediate state. Taking a snapshot before the stream starts means the in-flight request always uses the state from before streaming began.

Evidence: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:27-80`; `gotchas/captured-let-snapshot-in-sendable-closure.md`.
