# Lesson 10 — End-to-End Integration Testing

[Back to index](../index.md) | Prev: [Lesson 9](lesson-09-multiplatform-swift-packages.md) | Next: [Lesson 11](lesson-11-dockerizing-a-swift-server.md)

## Goal

After this lesson you can write end-to-end tests that exercise a view model talking to a live Hummingbird backend talking to a mocked upstream LLM — all in-process, no network.

## Prerequisites

[Lesson 7](lesson-07-hummingbird-http-services.md) — Hummingbird application setup.
[Lesson 8](lesson-08-swiftui-macos-app.md) — view model.

## Concepts

### 10.1 The end-to-end test chain

The capstone's `EndToEndTests` exercise the full stack:

```
ChatViewModel (macOS app layer)
  → BackendLLMService (URLSession to local backend)
  → Hummingbird router (chat-backend)
  → MockUpstreamLLMService (stands in for Anthropic)
```

This confirms: the view model talks to the backend, the backend talks to the LLM service, tokens flow back up, the view model renders them. Zero live network calls.

Evidence: `L-capstone-multiplatform-chat/Tests/CapstoneTests/EndToEndTests.swift:58-96`.

### 10.2 Why `app.test(.live)` cannot be dialled by `URLSession`

`HummingbirdTesting`'s `.live` client connects to the application via NIO's embedded channel — not a real TCP socket. `URLSession` cannot reach it. `app.test(.router)` skips the network layer entirely.

For URLSession-driven tests, you must start a real `Application` on port 0 and capture the OS-assigned port via the `onServerRunning` callback.

Evidence: `gotchas/hummingbird-test-live-vs-router-transport.md`.

### 10.3 `withLiveBackendForURLSession` helper

```swift
func withLiveBackendForURLSession(
    service: any LLMService,
    test: @escaping @Sendable (_ port: Int) async throws -> Void
) async throws {
    let portReady = AsyncStream<Int>.makeStream()
    let app = Application(
        router: buildRouter(service: service),
        configuration: .init(
            address: .hostname("127.0.0.1", port: 0),   // port 0 = OS picks a free port
            serverName: "chat-backend-test"
        ),
        onServerRunning: { @Sendable channel async in
            portReady.continuation.yield(channel.localAddress!.port!)
        }
    )
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await app.runService() }
        var port: Int? = nil
        for await p in portReady.stream { port = p; break }
        portReady.continuation.finish()
        guard let live = port else { group.cancelAll(); return }
        do {
            try await test(live)
        } catch { group.cancelAll(); throw error }
        group.cancelAll()
    }
}
```

The port-0 trick: the OS picks any available port; `onServerRunning` fires once the server is listening and yields the actual port through the `AsyncStream`.

Evidence: `L-capstone-multiplatform-chat/Tests/CapstoneTests/TestFixtures.swift:57-105`.

### 10.4 `MockUpstreamLLMService` for cross-isolation access

In end-to-end tests, the mock is touched by two isolation domains:
- The Hummingbird server task (calls `mock.stream(...)`)
- The test task (reads `mock.capturedRequests`)

Wrapping state in `NSLock` is required:

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
                for ev in events {
                    continuation.yield(ev)
                    await Task.yield()
                }
                continuation.finish()
            }
        }
    }
}
```

Evidence: `L-capstone-multiplatform-chat/Tests/CapstoneTests/MockUpstreamLLMService.swift:9-55`; `gotchas/unchecked-sendable-needed-for-test-mocks.md`.

### 10.5 Full chain test

```swift
@Test("Full chain: view model → backend → mock upstream → deltas accumulate")
@MainActor
func fullChain() async throws {
    let mock = MockUpstreamLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "Hello"),
        .contentBlockDelta(index: 0, textDelta: " world"),
        .messageStop
    ]

    try await withLiveBackendForURLSession(service: mock) { port in
        let backendURL = URL(string: "http://127.0.0.1:\(port)")!
        let vm = ChatViewModel(service: BackendLLMService(baseURL: backendURL))
        await vm.send(userText: "hi")
        #expect(vm.messages.count == 2)
        #expect(vm.messages[1].text == "Hello world")
        #expect(mock.capturedRequests.count == 1)
    }
}
```

Evidence: `L-capstone-multiplatform-chat/Tests/CapstoneTests/EndToEndTests.swift:58-96`.

### 10.6 `BackendLLMService` — the URLSession-based proxy client

The macOS app can talk to either `AnthropicClient` (direct) or `BackendLLMService` (via the Hummingbird backend). Both conform to the same `LLMService` protocol:

```swift
public struct BackendLLMService: LLMService, Sendable {
    public let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        let sessionCapture = session
        let requestCapture = request      // Capture immutable copies for Sendable closure
        return AsyncThrowingStream { continuation in
            let task = Task {
                // POST to /chat/stream, consume SSE lines, yield events
                // ...
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

Evidence: `L-capstone-multiplatform-chat/Sources/ChatCore/BackendLLMService.swift:7-78`.

## Pitfalls

- **Dialling `app.test(.live)` port from `URLSession`** → hangs. Use `withLiveBackendForURLSession` with port-0. See [ts-hummingbird-route-returns-404.md](../troubleshooting/ts-hummingbird-route-returns-404.md).
- **`MockUpstreamLLMService` without `NSLock`** → data race when server task and test task both access it.
- **Not cancelling the server task group on test completion** → the test hangs after assertions.

## Recap

- End-to-end tests: `ChatViewModel → BackendLLMService (URLSession) → live Hummingbird → MockUpstreamLLMService`.
- Use `withLiveBackendForURLSession` with `port: 0` to get a free port.
- `MockUpstreamLLMService` needs `@unchecked Sendable` + `NSLock` for cross-isolation access.
- `BackendLLMService` and `AnthropicClient` both conform to `LLMService` — the app can swap at runtime.
