# Assessment 2 — Swift 6 Strict Concurrency

[Back to index](../index.md) | Covers: [lesson-02-swift6-concurrency.md](../lessons/lesson-02-swift6-concurrency.md)

## Questions

**Q1.** The following code produces an error in Swift 6. What is the error, and what are two ways to fix it?

```swift
var apiURL: URL = URL(string: "https://api.anthropic.com")!
```

**Q2.** You have this code:

```swift
public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
    return AsyncThrowingStream { continuation in
        Task {
            let urlRequest = try self.buildURLRequest(for: request)
            // ...
        }
    }
}
```

Swift 6 rejects this. Why? Show the fix.

**Q3.** You write a test mock:

```swift
class MockLLMService: LLMService {
    var events: [StreamEvent] = []
}
```

Swift 6 refuses to compile it as conforming to a `Sendable` protocol. What annotation do you add and when is `NSLock` also needed?

**Q4.** What does `continuation.onTermination = { _ in task.cancel() }` accomplish? What happens if you omit it?

**Q5.** In Swift 6, what is wrong with this:

```swift
let service: LLMService
```

How do you fix it?

<details>
<summary>Answer Key</summary>

**A1.** Error: `var 'apiURL' is not concurrency-safe because it is nonisolated global shared mutable state`. Two fixes:
1. `let apiURL = URL(string: "...")!` — make it immutable.
2. `@MainActor var apiURL: URL = ...` — bind to main actor.

**A2.** `request` is a `var` parameter captured by a `@Sendable` closure. Swift 6 rejects mutable captures in concurrent closures. Fix: snapshot to a `let` before the closure:
```swift
var streamRequest = request
streamRequest.stream = true
let frozenRequest = streamRequest   // let snapshot
return AsyncThrowingStream { continuation in
    Task {
        let urlRequest = try self.buildURLRequest(for: frozenRequest)
        // ...
    }
}
```

**A3.** Add `@unchecked Sendable` to the class:
```swift
final class MockLLMService: LLMService, @unchecked Sendable { ... }
```
`NSLock` is also needed when the mock is accessed from multiple isolation domains simultaneously — e.g. in end-to-end tests where a Hummingbird server task calls `stream(...)` while the test task reads `capturedRequests`.

**A4.** When the consumer's `for try await` loop exits early (break, return, task cancelled, view disappears), the `AsyncThrowingStream` continuation terminates. The `onTermination` closure fires and cancels the producer `Task`. Without it, the underlying URLSession request keeps running after the consumer stops — a task and network resource leak.

**A5.** In Swift 6, existential types require the `any` keyword: `let service: any LLMService`. Without it, the compiler produces `error: use of protocol 'LLMService' as a type must be written 'any LLMService'`.

</details>
