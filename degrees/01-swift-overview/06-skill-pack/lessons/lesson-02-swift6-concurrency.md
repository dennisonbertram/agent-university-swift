# Lesson 2 — Swift 6 Strict Concurrency

[Back to index](../index.md) | Prev: [Lesson 1](lesson-01-swift-toolchain-and-swiftpm.md) | Next: [Lesson 3](lesson-03-typed-clients-with-codable.md)

## Goal

After this lesson you understand what Swift 6 strict concurrency enforces, how to structure types to satisfy the compiler, and how to use actors and `AsyncThrowingStream`.

## Prerequisites

[Lesson 1](lesson-01-swift-toolchain-and-swiftpm.md) — working Swift 6.1 toolchain and SwiftPM.

## Concepts

### 2.1 What changed in Swift 6

In Swift 5 (with `swift-tools-version: 5.x`), data-race warnings were opt-in. In Swift 6 (`swift-tools-version: 6.1`), **they are errors**. Every target compiled with Swift 6 language mode must satisfy the Sendable checker at compile time.

The rule: if a value crosses an isolation boundary (from one actor's context to another, or into a `@Sendable` closure), it must be `Sendable`.

### 2.2 Global mutable state

Any `var` at the top level of a file is a compile error in Swift 6:

```
error: var 'globalMutableVar' is not concurrency-safe because it is
nonisolated global shared mutable state
```

Fix options (in order of preference):

```swift
// 1. Make it immutable
let apiBaseURL = URL(string: "https://api.anthropic.com")!

// 2. Bind to MainActor (access is serialised on the main thread)
@MainActor var counter: Int = 0

// 3. Move into an actor
actor Counter { var value: Int = 0 }

// 4. Escape hatch when external locking is already in place
nonisolated(unsafe) var globalCache: [String: Any] = [:]
```

Evidence: `gotchas/swift6-global-mutable-state-is-error.md`; `01-research/01-language-and-concurrency.md §9`.

### 2.3 Sendable

A type is `Sendable` if it can be safely shared across isolation domains. The compiler synthesises `Sendable` for:
- Structs and enums whose stored properties are all `Sendable`.
- `final class` with no stored mutable properties, or that implements locking itself.

For types the compiler cannot synthesise, you declare conformance manually:

```swift
// Value type (struct): auto-synthesised if all fields are Sendable
public struct MessageRequest: Sendable { /* fields */ }

// Final class with verified external locking:
final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    var capturedRequests: [URLRequest] = []   // safe: test-only single-thread access
}
```

Use `@unchecked Sendable` only when you have an external guarantee (lock, single-thread, immutability). See [ts-sendable-type-cannot-be-marshalled.md](../troubleshooting/ts-sendable-type-cannot-be-marshalled.md).

### 2.4 `@MainActor`

Annotate a class or method `@MainActor` to bind all of its stored property access to the main thread. SwiftUI view models use this:

```swift
@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage] = []
    public var draft: String = ""
    // All reads and writes are on the main thread.
}
```

To mutate `@MainActor`-bound state from a background task:

```swift
await MainActor.run { self.appendDelta(toId: assistantId, chunk: chunk) }
```

Evidence: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:7`; `patterns/mainactor-observable-viewmodel.md`.

### 2.5 Actors

An `actor` serialises all access to its mutable state:

```swift
public actor ConversationActor {
    public private(set) var messages: [InputMessage] = []

    public func append(role: Role, text: String) {
        messages.append(InputMessage(role: role, content: .text(text)))
    }

    public func snapshot() -> [InputMessage] { messages }   // called with await
    public func removeLast() { if !messages.isEmpty { messages.removeLast() } }
}
```

Callers use `await` to enter the actor:

```swift
await history.append(role: .user, text: userText)
let snapshot = await history.snapshot()
```

The `snapshot()` pattern is load-bearing: take the immutable copy before starting a `@Sendable` closure so the closure never reaches back into the actor.

Evidence: `L3-cli-chat/Sources/ChatCore/ConversationActor.swift:4-30`; `patterns/actor-with-snapshot-reads.md`.

### 2.6 `AsyncThrowingStream` with cancellation

Wrap async producers (HTTP byte streams, actor mutations) in `AsyncThrowingStream`:

```swift
return AsyncThrowingStream { continuation in
    let task = Task {
        do {
            // ... produce values ...
            continuation.yield(someValue)
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }
    continuation.onTermination = { _ in task.cancel() }   // back-pressure to producer
}
```

The `onTermination` hook is critical: when the consumer's `for try await` loop exits early (break, throw, return, view disappears), the continuation terminates and the producer task is cancelled. Without it, the network request keeps running.

Evidence: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:51-90`; `patterns/asyncthrowingstream-with-onTermination.md`.

### 2.7 Captured `let` snapshots in `@Sendable` closures

The closure passed to `AsyncThrowingStream { continuation in ... }` is implicitly `@Sendable`. You cannot capture `self` or a `var` from the enclosing scope freely:

```
error: capture of 'self' with non-sendable type '<X>' in a `@Sendable` closure
error: reference to captured var '<X>' in concurrently-executing code
```

Fix: snapshot to local `let` values **outside** the closure:

```swift
public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
    var streamRequest = request
    streamRequest.stream = true
    let frozenRequest = streamRequest        // snapshot: immutable let

    return AsyncThrowingStream { continuation in
        Task {
            let urlRequest = try self.buildURLRequest(for: frozenRequest)  // capture let
            // ...
        }
    }
}
```

Evidence: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:52-55`; `gotchas/captured-let-snapshot-in-sendable-closure.md`.

### 2.8 The `any` keyword for existentials

Swift 6 requires `any` for protocol-typed variables:

```swift
// Wrong:
let service: LLMService        // error in Swift 6

// Correct:
let service: any LLMService
```

Evidence: `L3-cli-chat/Sources/ChatCore/ChatSession.swift`; `playbooks/playbook-debug-swift6-sendable-errors.md §4`.

## Walkthrough — Common Error → Fix Mapping

| Error | Cause | Fix |
|-------|-------|-----|
| `var 'X' is not concurrency-safe` | Top-level mutable `var` | Use `let`, `@MainActor var`, or an actor |
| `capture of 'self' in @Sendable closure` | Non-Sendable self captured by async closure | Snapshot to `let` outside the closure |
| `stored property 'X' of Sendable-conforming class is mutable` | Class mock holds mutable state | Add `@unchecked Sendable` + optional `NSLock` |
| `use of protocol 'X' as a type must be written 'any X'` | Missing `any` keyword | Add `any` before the protocol name |
| `'isolation()' only available in macOS 10.15+` | Missing `platforms:` | Add `platforms: [.macOS(.v13)]` to `Package.swift` |

Full playbook: [lessons/lesson-12-test-driven-development-in-swift.md](lesson-12-test-driven-development-in-swift.md) and [troubleshooting/ts-sendable-type-cannot-be-marshalled.md](../troubleshooting/ts-sendable-type-cannot-be-marshalled.md).

## Pitfalls

- **Over-using `@unchecked Sendable`**: every use should have a comment explaining the locking or single-thread guarantee. If you find yourself adding it more than once or twice, re-think the architecture.
- **Not checking `Task.checkCancellation()`** inside long producer loops: the task won't stop between suspension points unless you check.
- **Mutating actor state from inside a stream closure**: `await` the actor from inside the `Task {}`, not from inside the `AsyncThrowingStream` closure itself.

## Exercise

Complete [lab-04-streaming-counter.md](../labs/lab-04-streaming-counter.md): implement an `AsyncThrowingStream<Int, Error>` that yields 1..10 with cancellation support.

## Recap

- Swift 6 turns concurrency warnings into errors.
- No top-level `var` — use `let`, `@MainActor`, or `actor`.
- Types crossing isolation boundaries must be `Sendable`.
- Snapshot mutable state to `let` before `@Sendable` closures.
- `AsyncThrowingStream` with `continuation.onTermination = { _ in task.cancel() }` propagates cancellation.
- Always write `any LLMService`, not `LLMService`.
