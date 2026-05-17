# Pattern: end-to-end integration test — ViewModel ↔ real HTTP ↔ mocked upstream

**Category**: pattern

## What
A real Hummingbird `Application` is started on port 0; the OS-assigned port is captured via the `onServerRunning` callback. The system-under-test (a `URLSession`-backed `BackendLLMService` wired to a `@MainActor ChatViewModel`) connects over `127.0.0.1:<port>`. The upstream LLM is a `MockUpstreamLLMService` injected into the backend so no Anthropic call is made. After the test, the server is cancelled. This exercises the full chain — view model → URLSession → Hummingbird → router → upstream mock — with no live model spend.

## When to apply
- When you need confidence that the wire format actually round-trips: encoding, decoding, HTTP semantics, SSE framing.
- When unit tests against individual layers are already passing and you want a single end-to-end pin against drift.

## Canonical code

The helper (reusable across multiple tests):

```swift
import NIOConcurrencyHelpers
import NIOCore
import ServiceLifecycle
import Hummingbird

func withLiveBackendForURLSession(
    service: any LLMService,
    test: @escaping @Sendable (_ port: Int) async throws -> Void
) async throws {
    let portReady = AsyncStream<Int>.makeStream()
    let app = Application(
        router: buildRouter(service: service),
        configuration: .init(address: .hostname("127.0.0.1", port: 0), serverName: "chat-backend-test"),
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
        do { try await test(live) } catch { group.cancelAll(); throw error }
        group.cancelAll()
    }
}
```

The test that uses it:

```swift
@Test("ViewModel -> Backend -> Upstream: full streaming chain")
func fullChain() async throws {
    let upstream = MockUpstreamLLMService()
    upstream.events = [
        .messageStart(messageId: "m1"),
        .contentBlockDelta(index: 0, textDelta: "Hello"),
        .contentBlockDelta(index: 0, textDelta: " world"),
        .messageStop
    ]

    try await withLiveBackendForURLSession(service: upstream) { port in
        let backendURL = URL(string: "http://127.0.0.1:\(port)")!
        let session = URLSession(configuration: .ephemeral)
        let backendService = BackendLLMService(baseURL: backendURL, session: session)

        let capture = VMResultCapture()
        Task { @MainActor in
            let vm = ChatViewModel(service: backendService, model: "claude-test")
            await vm.send(userText: "hi")
            capture.deliver(VMResult(messages: vm.messages,
                                     isStreaming: vm.isStreaming,
                                     errorMessage: vm.errorMessage))
        }

        var result: VMResult? = nil
        for await r in capture.stream { result = r }
        let r = try #require(result)

        #expect(r.messages.count == 2)
        #expect(r.messages[1].text == "Hello world")
        #expect(r.isStreaming == false)
    }
}
```

## Variants and trade-offs
- The `VMResultCapture` bridge class is needed because `@MainActor` view-model state cannot be read directly from a non-MainActor test context without `await`; capturing into a Sendable result struct simplifies assertions.
- Use `URLSession(configuration: .ephemeral)` to avoid cookie / cache state bleeding between tests.
- This pattern is heavier than a unit test — only one or two end-to-end tests per surface are warranted. Most coverage stays in unit tests against the protocol seam.
- The pattern explicitly does NOT use `app.test(.live)` because Hummingbird's `.live` test client uses NIO transport, not real TCP that URLSession can reach. See gotcha `gotchas/hummingbird-test-live-vs-router-transport.md`.

## Evidence
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/TestFixtures.swift:57-105` — `withLiveBackendForURLSession`.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/EndToEndTests.swift:18-134` — full `fullChain` and `systemPromptRoundTrip` tests.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/BackendLLMServiceTests.swift:14-120` — three additional tests using the same helper.
- See also: gotcha `gotchas/hummingbird-test-live-vs-router-transport.md`, pattern `patterns/llm-service-protocol-seam.md`.
