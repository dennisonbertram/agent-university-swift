# Example — Capstone: `EndToEndTests` with Live Hummingbird Backend

[Back to index](../index.md) | POC: `degrees/01-swift-overview/03-pocs/L-capstone-multiplatform-chat/Tests/CapstoneTests/EndToEndTests.swift`

## What this example demonstrates

- End-to-end test chain: `ChatViewModel → BackendLLMService → live Hummingbird → MockUpstreamLLMService`.
- `withLiveBackendForURLSession` helper (port-0 trick).
- `MockUpstreamLLMService` with `NSLock` for cross-isolation access.

## `withLiveBackendForURLSession` helper

```swift
// TestFixtures.swift ~line 57
func withLiveBackendForURLSession(
    service: any LLMService,
    test: @escaping @Sendable (_ port: Int) async throws -> Void
) async throws {
    // AsyncStream bridges the onServerRunning callback to async code
    let portReady = AsyncStream<Int>.makeStream()

    let app = Application(
        router: buildRouter(service: service),
        configuration: .init(
            address: .hostname("127.0.0.1", port: 0),       // OS picks a free port
            serverName: "chat-backend-test"
        ),
        onServerRunning: { @Sendable channel async in
            portReady.continuation.yield(channel.localAddress!.port!)
        }
    )

    try await withThrowingTaskGroup(of: Void.self) { group in
        // Start the server in a child task
        group.addTask { try await app.runService() }

        // Wait for the port number
        var port: Int? = nil
        for await p in portReady.stream { port = p; break }
        portReady.continuation.finish()

        guard let live = port else { group.cancelAll(); return }

        // Run the test with the live port
        do {
            try await test(live)
        } catch {
            group.cancelAll()
            throw error
        }
        // Cancel the server after the test completes
        group.cancelAll()
    }
}
```

Source: `L-capstone-multiplatform-chat/Tests/CapstoneTests/TestFixtures.swift:57-105`.

## `MockUpstreamLLMService` — lock-wrapped for cross-isolation

```swift
// MockUpstreamLLMService.swift ~line 9
final class MockUpstreamLLMService: LLMService, @unchecked Sendable {
    private let lock = NSLock()
    private var _capturedRequests: [MessageRequest] = []

    // Safe to read from the test task even while the server task writes
    var capturedRequests: [MessageRequest] { lock.withLock { _capturedRequests } }

    var events: [StreamEvent] = []

    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        // Accessed from the Hummingbird server task — must lock
        lock.withLock { _capturedRequests.append(request) }
        let events = self.events
        return AsyncThrowingStream { continuation in
            Task {
                for ev in events {
                    continuation.yield(ev)
                    await Task.yield()     // allow mid-stream cancellation
                }
                continuation.finish()
            }
        }
    }
}
```

Source: `L-capstone-multiplatform-chat/Tests/CapstoneTests/MockUpstreamLLMService.swift:9-55`.

## The full chain test

```swift
// EndToEndTests.swift ~line 58
@Test("Full chain: view model streams through backend to mock upstream")
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
        // ChatViewModel → BackendLLMService (URLSession) → live Hummingbird → mock
        let vm = ChatViewModel(service: BackendLLMService(baseURL: backendURL))
        await vm.send(userText: "hi")

        // Assert the full chain delivered the text
        #expect(vm.messages.count == 2)
        #expect(vm.messages[1].text == "Hello world")
        #expect(vm.isStreaming == false)

        // Assert the upstream mock received the request
        #expect(mock.capturedRequests.count == 1)
        #expect(mock.capturedRequests[0].messages[0].role == .user)
    }
}
```

Source: `L-capstone-multiplatform-chat/Tests/CapstoneTests/EndToEndTests.swift:58-96`.

## What to notice

1. The test is `@MainActor` because `ChatViewModel` is `@MainActor`.

2. `withLiveBackendForURLSession` uses `port: 0` — the OS assigns a free port. This avoids port conflicts in parallel test runs.

3. `MockUpstreamLLMService` uses `NSLock` because it is accessed from two isolation domains: the Hummingbird request handler task (writes `_capturedRequests`) and the test task (reads `capturedRequests`).

4. After `await vm.send(userText: "hi")` returns, all stream events have been processed. The `await streamTask?.value` in `ChatViewModel.send` ensures the test doesn't race ahead.
