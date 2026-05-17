# `app.test(.live)` and `app.test(.router)` are NOT the same transport — URLSession cannot connect to either

**Category**: gotcha

## What
HummingbirdTesting offers two in-process clients: `.router` (calls the responder synchronously, no socket) and `.live` (starts a real server on a free port but the test client speaks the SwiftNIO test transport, not raw HTTP-over-TCP that `URLSession` knows). Neither can be used directly by a `URLSession`-backed Swift client. For end-to-end tests that exercise URLSession, you must start the application yourself, wait for `onServerRunning`, and dial back in over `127.0.0.1:<port>`.

## Symptom
Test using `BackendLLMService(baseURL: URL(string: "http://127.0.0.1:\(testClient.port)"))` hangs or times out. The Hummingbird test client succeeds when called via `client.execute(uri:...)` but real `URLSession` calls cannot reach it.

## Cause
`HummingbirdTesting`'s `.live` test client connects to the application through NIO's `EmbeddedChannel`-style plumbing — there is no listening TCP socket from `URLSession`'s point of view. `app.test(.router)` skips the network layer entirely.

## Fix
For URLSession-driven end-to-end tests, build your own helper that runs the real `Application` service on port 0 and waits for the OS-assigned port via the `onServerRunning` callback:

```swift
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
        do {
            try await test(live)
        } catch { group.cancelAll(); throw error }
        group.cancelAll()
    }
}
```

Use `app.test(.live)` only when your test code itself is the Hummingbird test client. Use the helper above when the system under test holds a `URLSession`.

## Evidence
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/TestFixtures.swift:57-105` — full `withLiveBackendForURLSession` helper.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/EndToEndTests.swift:58-96` — `fullChain` test consumes it.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/BackendLLMServiceTests.swift:20-46` — `unauthorizedResponseSurfacesError` uses the helper because the test exercises `BackendLLMService(baseURL:)`, which is URLSession-backed.
- Compare: `L4-hummingbird-tool-service/Tests/ToolServiceTests/ChatStreamEndpointTests.swift:26` — uses `app.test(.live)` because the test client itself is Hummingbird's, not URLSession.
