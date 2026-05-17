# Recipe — `MockLLMService` with Canned Events and Captured Requests

[Back to index](../index.md) | See also: [lesson-12-test-driven-development-in-swift.md](../lessons/lesson-12-test-driven-development-in-swift.md) | Pattern: `patterns/mock-service-with-canned-events.md`

## Use this when

You need to test a layer that calls an `LLMService` without making live Anthropic API calls.

## Basic mock (single-isolation access)

```swift
import AnthropicClient
@testable import ChatCore

final class MockLLMService: LLMService, @unchecked Sendable {
    var events: [StreamEvent] = []
    var error: Error?
    private(set) var capturedRequests: [MessageRequest] = []

    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        capturedRequests.append(request)
        let events = self.events   // snapshot for @Sendable closure
        let error = self.error
        return AsyncThrowingStream { continuation in
            Task {
                for ev in events {
                    continuation.yield(ev)
                    await Task.yield()   // let consumers cancel between events
                }
                if let error { continuation.finish(throwing: error) }
                else { continuation.finish() }
            }
        }
    }
}
```

Evidence: `L3-cli-chat/Tests/ChatCoreTests/MockLLMService.swift`.

## Lock-wrapped mock (cross-isolation access)

When the mock is accessed by both the server task and the test task:

```swift
final class MockUpstreamLLMService: LLMService, @unchecked Sendable {
    private let lock = NSLock()
    private var _capturedRequests: [MessageRequest] = []
    var capturedRequests: [MessageRequest] { lock.withLock { _capturedRequests } }

    var events: [StreamEvent] = []

    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        lock.withLock { _capturedRequests.append(request) }
        let events = self.events
        return AsyncThrowingStream { continuation in
            Task {
                for ev in events { continuation.yield(ev); await Task.yield() }
                continuation.finish()
            }
        }
    }
}
```

Evidence: `L-capstone-multiplatform-chat/Tests/CapstoneTests/MockUpstreamLLMService.swift:9-55`.

## Factory helpers

```swift
extension MockLLMService {
    static func make(texts: [String]) -> MockLLMService {
        let mock = MockLLMService()
        mock.events = texts.map { .contentBlockDelta(index: 0, textDelta: $0) } + [.messageStop]
        return mock
    }

    static func makeFailure(_ error: Error) -> MockLLMService {
        let mock = MockLLMService()
        mock.error = error
        return mock
    }

    static func makeHappyPath() -> MockLLMService {
        make(texts: ["Hello", " world", "!"])
    }
}
```

## Usage in a test

```swift
@Test("BT-003: three deltas + messageStop → consumer gets three chunks")
func happyPathStreaming() async throws {
    let mock = MockLLMService.make(texts: ["Hel", "lo", "!"])
    let session = ChatSession(service: mock, model: "test", maxTokens: 100)
    var received: [String] = []
    for try await chunk in session.send(userText: "hi") { received.append(chunk) }
    #expect(received == ["Hel", "lo", "!"])
    #expect(mock.capturedRequests.count == 1)
    #expect(mock.capturedRequests[0].stream == true)
}
```

## When to use basic vs lock-wrapped

| Scenario | Mock type |
|----------|-----------|
| Unit tests where mock is only touched by the test task | Basic `@unchecked Sendable` |
| End-to-end tests where Hummingbird server task calls `stream` and test task reads `capturedRequests` | Lock-wrapped with `NSLock` |
