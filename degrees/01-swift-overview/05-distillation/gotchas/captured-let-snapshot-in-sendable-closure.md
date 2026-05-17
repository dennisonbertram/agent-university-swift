# `AsyncThrowingStream { continuation in ... }` closures must capture immutable snapshots — `self` and mutable params won't cross

**Category**: gotcha

## What
The closure passed to `AsyncThrowingStream { continuation in ... }` is implicitly `@Sendable` and executes on its own task. Inside, you cannot freely reference `self`, `var` parameters, or anything mutable from the enclosing scope. Captured values must be immutable (`let`) snapshots; large structs are usually copied just before the closure.

## Symptom
```
error: capture of 'self' with non-sendable type '<X>' in a `@Sendable` closure
error: reference to captured var '<X>' in concurrently-executing code
error: 'request' used before being passed to non-isolated context
```

## Cause
Swift 6 enforces region-based isolation. A `@Sendable` closure forms its own isolation region and the compiler must prove every captured value is safe to share.

## Fix
Snapshot to local `let`s *outside* the closure body, then capture those:

```swift
public func send(userText: String) -> AsyncThrowingStream<String, Error> {
    let service = self.service             // let snapshot
    let model = self.model
    let maxTokens = self.maxTokens
    let system = self.system
    let history = self.history

    return AsyncThrowingStream { continuation in
        let task = Task {
            await history.append(role: .user, text: userText)
            let snapshot = await history.snapshot()
            let req = MessageRequest(
                model: model,
                maxTokens: maxTokens,
                messages: snapshot,
                system: system,
                temperature: nil,
                stream: true
            )
            // ...
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

For closures that need a mutated request (e.g. flipping `stream = true`), build the modified struct first, then `let frozenRequest = streamRequest` so the closure only sees the immutable copy:

```swift
public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
    var streamRequest = request
    streamRequest.stream = true
    let frozenRequest = streamRequest        // <-- snapshot

    return AsyncThrowingStream { continuation in
        Task {
            let urlRequest = try self.buildURLRequest(for: frozenRequest)
            // ...
        }
    }
}
```

## Evidence
- POC: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:27-45` — snapshot pattern for an actor-isolated struct method: every captured field is bound to a local `let` before the stream closure.
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:52-55` — `var streamRequest = request; streamRequest.stream = true; let frozenRequest = streamRequest`.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/BackendLLMService.swift:20-23` — `let sessionCapture = session; let requestCapture = request` immediately inside the stream closure comment: "Capture immutable copies for Sendable closure".
- Research: `01-research/01-language-and-concurrency.md` §11 lines 451-458 — `Capture of mutable var in async closure` failure mode.
- See also: pattern `patterns/asyncthrowingstream-with-onTermination.md`.
