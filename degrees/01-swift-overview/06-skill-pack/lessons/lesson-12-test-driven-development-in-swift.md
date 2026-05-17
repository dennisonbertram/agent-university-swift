# Lesson 12 — Test-Driven Development in Swift

[Back to index](../index.md) | Prev: [Lesson 11](lesson-11-dockerizing-a-swift-server.md)

## Goal

After this lesson you follow the red/green/regression TDD commit trail used across all POCs, write maintainable swift-testing test suites, and build `MockXyzService` factories for reliable test coverage.

## Prerequisites

[Lesson 1](lesson-01-swift-toolchain-and-swiftpm.md) — swift-testing basics.

## Concepts

### 12.1 Red/green/regression commit trail

Each behavioural change follows three commits:

1. **Red**: introduce a failing test that names the expected behaviour. Source may be a stub.
2. **Green**: implement the minimum code to make the test pass. No extra polish.
3. **Regression**: add a separate test in `RegressionTests.swift` that pins something specific — a header value, a field format, an architectural invariant. Numbered `REGRESSION-NNN: <description>`.

The regression tests are separate files so the named pins are visible and searchable.

Evidence: `patterns/red-green-regression-tdd-trail.md`; `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift`.

### 12.2 swift-testing core API

```swift
import Testing

// Basic test
@Test("Human-readable description")
func myTest() {
    #expect(1 + 1 == 2)
}

// Throws on failure (unwrap optional or throw)
@Test func parseTest() throws {
    let s = try #require(optional_that_might_be_nil)
    #expect(s == "expected")
}

// Suite groups related tests
@Suite("Greeter")
struct GreeterTests {
    @Test("Named") func named() { #expect(greet(name: "Bob") == "Hello, Bob!") }
}

// Parameterized tests
@Test("Multiple inputs", arguments: [("Alice", "Hello, Alice!"), ("", "Hello, stranger!")])
func parameterized(name: String, expected: String) {
    #expect(greet(name: name) == expected)
}

// Async test
@Test func asyncTest() async throws {
    let result = try await someAsyncWork()
    #expect(result == "expected")
}

// MainActor-isolated test suite (for @MainActor view models)
@MainActor
@Suite("ChatViewModel")
struct ChatViewModelTests { /* ... */ }
```

### 12.3 Naming convention

The corpus uses `BT-NNN: <description>` for behavioural tests and `REGRESSION-NNN: <description>` for regression pins:

```swift
@Test("BT-004: error before delta rolls back user message")
func errorBeforeDeltaRollsBackUser() async throws { /* ... */ }

@Test("REGRESSION-001: system prompt is forwarded in every request")
func systemPromptForwarded() async throws { /* ... */ }
```

This makes CI log output scannable. When a regression fires, the name tells you exactly what broke.

Evidence: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:38-181`.

### 12.4 `MockLLMService` with canned events

```swift
import AnthropicClient
@testable import ChatCore

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
                    await Task.yield()          // let consumer cancel between events
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
@Test("BT-003: three deltas + messageStop → consumer gets 3 chunks")
func happyPathStreaming() async throws {
    let mock = MockLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "Hel"),
        .contentBlockDelta(index: 0, textDelta: "lo"),
        .contentBlockDelta(index: 0, textDelta: "!"),
        .messageStop
    ]
    let session = ChatSession(service: mock, model: "test-model", maxTokens: 100)
    var received: [String] = []
    for try await chunk in session.send(userText: "hi") { received.append(chunk) }
    #expect(received == ["Hel", "lo", "!"])
    #expect(mock.capturedRequests.count == 1)
}
```

Evidence: `patterns/mock-service-with-canned-events.md`; `L3-cli-chat/Tests/ChatCoreTests/MockLLMService.swift`.

### 12.5 Factory helpers for common test setups

For richer mocks, add factory helpers so tests stay short:

```swift
extension MockLLMService {
    static func make(texts: [String]) -> MockLLMService {
        let mock = MockLLMService()
        mock.events = texts.map { .contentBlockDelta(index: 0, textDelta: $0) } + [.messageStop]
        return mock
    }

    static func makeFailure(error: Error) -> MockLLMService {
        let mock = MockLLMService()
        mock.error = error
        return mock
    }
}
```

Evidence: `L4-hummingbird-tool-service/Tests/ToolServiceTests/MockLLMService.swift:34-60`.

### 12.6 Regression test that reads source files

For architectural invariants (e.g. "the view model must not import SwiftUI"), read the source file from disk inside the test:

```swift
@Test("REGRESSION-002: ChatViewModel.swift contains no 'import SwiftUI'")
func chatViewModelHasNoSwiftUIImport() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let vmPath = packageRoot.appendingPathComponent("Sources/ChatCoreShared/ChatViewModel.swift")
    let source = try String(contentsOf: vmPath, encoding: .utf8)
    #expect(!source.contains("import SwiftUI"))
}
```

`#filePath` gives the test file's path at compile time; navigating up three levels reaches the package root.

Evidence: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/RegressionTests.swift:60-108`; `L-capstone-multiplatform-chat/Tests/CapstoneTests/RegressionTests.swift`.

### 12.7 Test file layout

```
Tests/
  <Module>Tests/
    <Module>Tests.swift          # behavioural tests: @Suite, BT-NNN
    RegressionTests.swift        # regression pins: REGRESSION-NNN
    Mock<X>.swift                # mock implementations
    TestFixtures.swift           # helpers: withLiveBackendForURLSession, makeByteStream(from:)
```

Every POC follows this layout exactly.

### 12.8 Diagnostic messages in assertions

Put the rationale in the assertion message so a future agent reading red CI logs understands:

```swift
#expect(req.stream == true,
        "stream must be true; if nil/false, streaming was accidentally disabled")

#expect(response.headers[.contentType] == "text/event-stream",
        "SSE endpoint must set Content-Type: text/event-stream")
```

## Pitfalls

- **Not using `await Task.yield()` between mock events** → the consumer never gets a chance to cancel mid-stream, so cancellation tests can't be written.
- **Putting regression pins inside the main test suite** → they're harder to grep and the naming convention (`REGRESSION-NNN`) is obscured.
- **Using real network in tests** → flaky, slow, depends on `ANTHROPIC_API_KEY` being set. Every test in the corpus uses a mock.

## Recap

- Three commits per behaviour: red → green → regression.
- Regressions go in `RegressionTests.swift` with `REGRESSION-NNN: ...` names.
- `MockLLMService` is `@unchecked Sendable` with canned events and captured requests.
- `await Task.yield()` between mock events allows cancellation tests.
- Factory helpers keep tests short and readable.
- `#filePath` + source-file reading for architectural invariant pins.
