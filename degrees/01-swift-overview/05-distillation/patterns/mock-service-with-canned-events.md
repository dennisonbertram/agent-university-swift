# Pattern: `Mock<X>Service` with canned events and captured-request log

**Category**: pattern

## What
Every consumer of the LLM service in this corpus ships a `MockLLMService` (or `MockHTTPTransport` for the raw byte layer) in tests. The mock is `final class ... @unchecked Sendable`. It exposes:
- A configurable list of canned `StreamEvent`s (or canned `Message` for non-streaming).
- An optional `error: Error?` for failure-injection.
- A `private(set) var capturedRequests: [MessageRequest]` (or `[URLRequest]`) so the test can assert what was sent.

This is the seam that makes every test in the corpus run with zero network calls.

## When to apply
- Every test target. The corpus has a `MockLLMService.swift` in L3, L4, L5, L6, and `MockUpstreamLLMService.swift` in the capstone.

## Canonical code

```swift
import AnthropicClient
@testable import ChatCore   // or ChatAppCore, ChatCoreShared, ToolService, etc.

final class MockLLMService: LLMService, @unchecked Sendable {
    var events: [StreamEvent] = []
    var error: Error?
    private(set) var capturedRequests: [MessageRequest] = []

    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        capturedRequests.append(request)
        let events = self.events
        let error = self.error
        return AsyncThrowingStream { continuation in
            Task {
                for ev in events {
                    continuation.yield(ev)
                    await Task.yield()                  // let consumers cancel between events
                }
                if let error { continuation.finish(throwing: error) }
                else { continuation.finish() }
            }
        }
    }
}
```

Usage in a test:
```swift
@Test("BT-003: mock yields 3 deltas + messageStop → consumer gets 3 chunks")
func happyPathStreaming() async throws {
    let mock = MockLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "Hel"),
        .contentBlockDelta(index: 0, textDelta: "lo"),
        .contentBlockDelta(index: 0, textDelta: "!"),
        .messageStop
    ]
    let session = ChatSession(service: mock, model: "test-model")
    var received: [String] = []
    for try await chunk in session.send(userText: "hi") { received.append(chunk) }
    #expect(received == ["Hel", "lo", "!"])
    #expect(mock.capturedRequests.count == 1)
}
```

## Variants and trade-offs
- For mocks the system-under-test touches from multiple isolation domains (server task + test task), wrap state in `NSLock` — see `L-capstone-multiplatform-chat/Tests/CapstoneTests/MockUpstreamLLMService.swift:9-31`.
- `await Task.yield()` between events lets the consumer's cancellation path observe partial progress — exercised by `consumerCancelsEarly` in L3.
- For richer mocks, expose factory helpers (`MockLLMService.makeStreamEvents(texts: ["a","b"])`, `makeCannedMessage(text:)`) so tests are short — see `L4-hummingbird-tool-service/Tests/ToolServiceTests/MockLLMService.swift:34-60`.
- Captured requests are the regression mechanism: REGRESSION-001 in L3, REGRESSION-001 in L5/L6, and REGRESSION-002 in L6 all assert on `mock.capturedRequests[0].<field>`.

## Evidence
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/MockHTTPTransport.swift:6-56` — transport-layer mock.
- POC: `L3-cli-chat/Tests/ChatCoreTests/MockLLMService.swift:5-25` — LLMService mock.
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/MockLLMService.swift:22-97` — mock with two surfaces and factory helpers.
- POC: `L5-swiftui-macos-app/Tests/ChatAppCoreTests/MockLLMService.swift` — view-model mock.
- POC: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/MockLLMService.swift` — same shape, multiplatform package.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/MockUpstreamLLMService.swift:9-55` — lock-wrapped variant for cross-isolation access.
- See also: pattern `patterns/llm-service-protocol-seam.md`, gotcha `gotchas/unchecked-sendable-needed-for-test-mocks.md`.
