# Troubleshooting — Hummingbird Route Returns 404

[Back to index](../index.md)

## Symptom

A route you registered returns HTTP 404. The `buildRouter` function looks correct. In-process tests pass when using `app.test(.router)` or `app.test(.live)` with Hummingbird's test client, but a `URLSession` request to the same server returns 404.

## Diagnosis

**Cause 1 — URLSession cannot reach `app.test(.live)`:**
`HummingbirdTesting`'s `.live` client uses NIO's embedded channel — not a real listening TCP socket. `URLSession.data(for:)` cannot dial it. The route exists in the application but `URLSession` cannot find the server.

**Cause 2 — Route registered before middleware (unrelated 404):**
Less likely, but if middleware throws an error or rejects the request, it returns 404 for unregistered paths.

## Fix for URLSession in tests

For end-to-end tests that exercise `URLSession`, start the application with `port: 0` and capture the assigned port:

```swift
func withLiveBackendForURLSession(
    service: any LLMService,
    test: @escaping @Sendable (_ port: Int) async throws -> Void
) async throws {
    let portReady = AsyncStream<Int>.makeStream()
    let app = Application(
        router: buildRouter(service: service),
        configuration: .init(address: .hostname("127.0.0.1", port: 0),
                             serverName: "test"),
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
        do { try await test(live) }
        catch { group.cancelAll(); throw error }
        group.cancelAll()
    }
}
```

Then in the test:

```swift
try await withLiveBackendForURLSession(service: mock) { port in
    let url = URL(string: "http://127.0.0.1:\(port)/health")!
    let (data, response) = try await URLSession.shared.data(from: url)
    // ...
}
```

Evidence: `L-capstone-multiplatform-chat/Tests/CapstoneTests/TestFixtures.swift:57-105`.

## See also

- Distillation: `gotchas/hummingbird-test-live-vs-router-transport.md`
- Lesson: [lesson-07-hummingbird-http-services.md](../lessons/lesson-07-hummingbird-http-services.md)
- Lesson: [lesson-10-end-to-end-integration-testing.md](../lessons/lesson-10-end-to-end-integration-testing.md)
