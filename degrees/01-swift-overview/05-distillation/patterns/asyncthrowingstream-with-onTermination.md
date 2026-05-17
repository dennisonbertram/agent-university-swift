# Pattern: `AsyncThrowingStream` continuation with `onTermination` to propagate cancellation

**Category**: pattern

## What
Wrap an async producer (HTTP body, actor mutations, byte stream) in `AsyncThrowingStream { continuation in ... }`. Spawn the producer as a `Task` inside the closure, retain that task in a local `let`, and set `continuation.onTermination = { _ in task.cancel() }`. When the consumer's `for try await` loop breaks early (return / throw / out-of-scope), the stream is terminated and the producer task is cancelled. No leaked tasks, no orphan URLSession reads.

## When to apply
- Any time you turn an `AsyncSequence` (SSE bytes, file lines, websocket frames) into a typed event stream.
- Any time you wrap a long-running multi-step pipeline (request → response → parse → yield) so the consumer can `break` and have the upstream work stop.
- Whenever you say "the user pressed Stop" — `onTermination` is what makes that work.

## Canonical code

```swift
public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
    var streamRequest = request
    streamRequest.stream = true
    let frozenRequest = streamRequest

    return AsyncThrowingStream { continuation in
        let task = Task {
            do {
                let urlRequest = try self.buildURLRequest(for: frozenRequest)
                let (byteStream, response) = try await self.transport.bytes(urlRequest)

                guard response.statusCode == 200 else {
                    continuation.finish(throwing: AnthropicError.serverError(status: response.statusCode, body: ""))
                    return
                }

                let eventStream = SSEParser.parse(bytes: byteStream)
                for try await event in eventStream {
                    try Task.checkCancellation()
                    continuation.yield(event)
                    if case .messageStop = event {
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

Consumer-side cancellation just breaks out of the loop:
```swift
for try await chunk in session.send(userText: "go") {
    if shouldStop { break }              // triggers continuation.onTermination → task.cancel()
}
```

## Variants and trade-offs
- The `continuation.onTermination` handler runs on an arbitrary executor and is `@Sendable`. Capture only `let task: Task<...>` or other `Sendable` values.
- Sprinkle `try Task.checkCancellation()` inside the producer loop so cancellation is observed in addition to async-suspension points.
- The same shape applies when bridging actor work (`ChatSession.send`), HTTP streams (`AnthropicClient.stream`), and proxy backends (`BackendLLMService.stream`).
- For non-cancelling streams you can omit `onTermination`, but then a broken loop leaves the producer running until it naturally completes — usually undesirable for network reads.

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:51-90` — full pattern around an HTTP stream.
- POC: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:34-79` — same pattern with actor-backed history; explicit `continuation.onTermination = { _ in task.cancel() }` on line 78.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/BackendLLMService.swift:19-77` — proxy-mode SSE consumer; line 75 sets `onTermination`.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/BackendLLMServiceTests.swift:50-85` — `cancellationMidStream` test exercises the path.
- Research: `01-research/01-language-and-concurrency.md` §10 lines 341-385 — `AsyncThrowingStream` reference.
- See also: gotcha `gotchas/captured-let-snapshot-in-sendable-closure.md`.
