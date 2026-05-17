# Reference — Swift 6 Concurrency Keywords

[Back to index](../index.md)

## `Sendable`

A type that can be safely passed across isolation boundaries (actor hops, `@Sendable` closures).

```swift
// Struct: auto-synthesised if all stored properties are Sendable
public struct MessageRequest: Codable, Sendable, Equatable { /* ... */ }

// Enum: auto-synthesised if all associated values are Sendable
public enum Role: String, Codable, Sendable { case user, assistant }

// Final class: must declare manually
public final class AnthropicClient: Sendable { /* only immutable stored properties */ }
```

## `@unchecked Sendable`

Opt out of the compiler's Sendable check. **Requires a manual guarantee** (single-thread access, lock, or immutability):

```swift
// For test mocks accessed from a single thread:
final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    var capturedRequests: [URLRequest] = []   // only accessed by the test task
}

// For mocks accessed from multiple isolation domains — add NSLock:
final class MockUpstreamLLMService: LLMService, @unchecked Sendable {
    private let lock = NSLock()
    private var _capturedRequests: [MessageRequest] = []
    var capturedRequests: [MessageRequest] { lock.withLock { _capturedRequests } }
}
```

## `@MainActor`

Binds all access to the main thread. Used on view models:

```swift
@MainActor
@Observable
public final class ChatViewModel { /* all reads/writes on main thread */ }
```

Calling from a background task:
```swift
await MainActor.run { self.appendDelta(chunk: chunk) }
```

## `actor`

Serialises all access to its mutable state:

```swift
public actor ConversationActor {
    private var messages: [InputMessage] = []
    public func append(role: Role, text: String) { /* ... */ }
    public func snapshot() -> [InputMessage] { messages }
}

// Call with await:
await history.append(role: .user, text: "hi")
let snapshot = await history.snapshot()
```

## `nonisolated`

Opts a member out of an actor or `@MainActor` constraint:

```swift
actor Counter {
    var value: Int = 0

    nonisolated var description: String {
        // Must not access actor-isolated state
        return "Counter"
    }
}
```

## `nonisolated(unsafe)`

Escape hatch for global mutable state with external locking:

```swift
nonisolated(unsafe) var globalCache: [String: Any] = [:]
// Must document the locking guarantee
```

## `any` keyword for existentials

Required in Swift 6 for protocol-typed variables:

```swift
// Correct:
let service: any LLMService
let transport: any HTTPTransport

// Wrong (Swift 6 compile error):
let service: LLMService
```

## `AsyncThrowingStream` patterns

```swift
// Producer with cancellation
return AsyncThrowingStream { continuation in
    let task = Task {
        // ... produce values ...
        continuation.yield(value)
        continuation.finish()
    }
    continuation.onTermination = { _ in task.cancel() }   // propagate cancellation
}

// Let snapshot before the closure (avoids capturing mutable self)
let frozenRequest = streamRequest   // let snapshot
return AsyncThrowingStream { continuation in
    Task { let req = try self.build(frozenRequest); /* ... */ }
}
```

Evidence: `01-research/01-language-and-concurrency.md §8-§12`; `playbooks/playbook-debug-swift6-sendable-errors.md`.
