# Test mocks for `Sendable` protocols often need `@unchecked Sendable` plus careful state handling

**Category**: gotcha

## What
The transport / service protocols in this corpus are declared `Sendable` (so the production actor stays Sendable-clean). When you write a test mock that holds mutable captured-request lists, Swift 6 refuses to synthesise `Sendable` conformance for the mock class. You need `@unchecked Sendable` plus either a lock or single-thread access.

## Symptom
```
error: stored property '<X>' of 'Sendable'-conforming class '<MockType>' is mutable
```

## Cause
A `final class` with mutable stored properties cannot be automatically `Sendable` — there is no compiler-checkable proof of thread safety. Refusing the conformance would mean the mock cannot satisfy the protocol whose live implementation is `Sendable`.

## Fix
- For simple single-threaded test access (most swift-testing tests), the explicit `@unchecked Sendable` is fine:
  ```swift
  final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
      var capturedRequests: [URLRequest] = []
      var dataResponse: (Data, HTTPURLResponse)?
      // ...
  }
  ```
- For mocks that may be accessed from multiple isolation domains (e.g. an upstream mock that the backend's `service.stream(_:)` is called from a Hummingbird handler task while the test thread reads back captured requests), wrap state in `NSLock`:
  ```swift
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

## Evidence
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/MockHTTPTransport.swift:6` — `final class MockHTTPTransport: HTTPTransport, @unchecked Sendable`.
- POC: `L3-cli-chat/Tests/ChatCoreTests/MockLLMService.swift:5` — same pattern.
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/MockLLMService.swift:22` — `final class MockLLMService: LLMService, @unchecked Sendable`.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/MockUpstreamLLMService.swift:9-31` — `@unchecked Sendable` PLUS explicit `NSLock`, because the mock is touched by the Hummingbird server task and the test task.
- Research: `01-research/01-language-and-concurrency.md` §9 lines 284-300 — `@unchecked Sendable` escape hatch documentation.
