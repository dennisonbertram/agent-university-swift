# Troubleshooting — Sendable / capture errors in async closures

[Back to index](../index.md)

## Symptoms

```
error: capture of 'self' with non-sendable type '<X>' in a `@Sendable` closure
error: reference to captured var '<X>' in concurrently-executing code
error: 'request' used before being passed to non-isolated context
error: stored property '<X>' of 'Sendable'-conforming class '<MockType>' is mutable
```

## Diagnosis

**Case 1 — Captured `var` or `self`:**
The closure passed to `AsyncThrowingStream { continuation in ... }` is implicitly `@Sendable`. Capturing a `var` or a non-`Sendable` `self` from the enclosing scope is rejected by Swift 6.

**Case 2 — Mock class holds mutable state:**
A `final class` conforming to a `Sendable` protocol cannot have synthesised `Sendable` if it holds mutable stored properties.

## Fixes

**Case 1 — Snapshot to `let` before the closure:**

```swift
public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
    var streamRequest = request
    streamRequest.stream = true
    let frozenRequest = streamRequest         // ← immutable let
    let service = self.service                // ← let snapshot of self's property

    return AsyncThrowingStream { continuation in
        Task {
            let urlRequest = try service.buildURLRequest(for: frozenRequest)
            // ...
        }
    }
}
```

**Case 2 — `@unchecked Sendable` for test mocks:**

```swift
// Single-threaded test access: @unchecked Sendable alone
final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    var capturedRequests: [URLRequest] = []
}

// Cross-isolation access (server task + test task): add NSLock
final class MockUpstreamLLMService: LLMService, @unchecked Sendable {
    private let lock = NSLock()
    private var _capturedRequests: [MessageRequest] = []
    var capturedRequests: [MessageRequest] { lock.withLock { _capturedRequests } }
    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        lock.withLock { _capturedRequests.append(request) }
        // ...
    }
}
```

## See also

- Distillation: `gotchas/captured-let-snapshot-in-sendable-closure.md`, `gotchas/unchecked-sendable-needed-for-test-mocks.md`
- Lesson: [lesson-02-swift6-concurrency.md](../lessons/lesson-02-swift6-concurrency.md)
- Playbook: `playbooks/playbook-debug-swift6-sendable-errors.md`
