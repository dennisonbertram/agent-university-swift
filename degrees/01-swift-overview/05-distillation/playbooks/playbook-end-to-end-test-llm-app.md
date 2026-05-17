# Playbook: end-to-end test of a streaming LLM app — ViewModel ↔ real HTTP ↔ mocked upstream

**Goal**: A single integration test that exercises a `@MainActor` view model talking via real `URLSession` to a real Hummingbird backend, where the backend's upstream is a mock. No live Anthropic call.

## Prerequisites
- Multiplatform SwiftPM package with three logical targets: shared core (ChatCore), backend library (ChatBackendLib), tests (CapstoneTests).
- The backend library uses the same `LLMService` protocol that both the real Anthropic client and the upstream mock conform to.

## Steps

1. Build a Sendable result bridge. The test reads `@MainActor` view-model state but assertions run in a non-MainActor test context. Capture state into a `VMResult` struct via an `AsyncStream` continuation:
   ```swift
   struct VMResult: Sendable {
       let messages: [ChatMessage]
       let isStreaming: Bool
       let errorMessage: String?
   }

   final class VMResultCapture: @unchecked Sendable {
       private let continuation: AsyncStream<VMResult>.Continuation
       let stream: AsyncStream<VMResult>
       init() {
           var cont: AsyncStream<VMResult>.Continuation!
           stream = AsyncStream<VMResult> { cont = $0 }
           continuation = cont
       }
       func deliver(_ r: VMResult) { continuation.yield(r); continuation.finish() }
   }
   ```

2. Build the live-backend helper. URLSession cannot connect to `app.test(.live)` directly (see gotcha `gotchas/hummingbird-test-live-vs-router-transport.md`), so spin up a real Application on port 0 and capture the OS-assigned port via `onServerRunning`:
   ```swift
   func withLiveBackendForURLSession(
       service: any LLMService,
       test: @escaping @Sendable (_ port: Int) async throws -> Void
   ) async throws {
       let portReady = AsyncStream<Int>.makeStream()
       let app = Application(
           router: buildRouter(service: service),
           configuration: .init(address: .hostname("127.0.0.1", port: 0),
                                serverName: "chat-backend-test"),
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

3. Build a `MockUpstreamLLMService` that conforms to the same `LLMService` protocol the production `AnthropicClient` does, with lock-wrapped state because both the server task and the test task touch it (see gotcha `gotchas/unchecked-sendable-needed-for-test-mocks.md`).

4. Write the test:
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
               let vm = ChatViewModel(service: backendService, model: "claude-test", system: "be brief")
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
           #expect(upstream.capturedRequests.count == 1)
       }
   }
   ```

5. Verify the test runs in a reasonable time (under 1 second). If it hangs, the most common culprits are:
   - Missing terminator: backend doesn't emit `event: done\ndata: [DONE]\n\n` so `BackendLLMService` never finishes.
   - Stream NOT set: request has `stream: nil`; see anti-pattern `anti-patterns/forgetting-stream-true-on-streaming-request.md`.
   - URLSession session.invalidateAndCancel() not configured; use `.ephemeral` to avoid lingering state.

## You'll know it worked when…
- The test passes in under 1 second.
- `upstream.capturedRequests[0].system == "be brief"` — confirming the system prompt survives encoding/decoding/network/decoding round-trip.
- `r.messages[1].text == "Hello world"` — confirming SSE deltas accumulate correctly through three layers.

## Evidence
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/EndToEndTests.swift:1-134` — `fullChain` and `systemPromptRoundTrip` tests.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/TestFixtures.swift:14-105` — `TestFixtures`, `VMResultCapture`, `withLiveBackendForURLSession`.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/MockUpstreamLLMService.swift:9-55` — lock-wrapped upstream mock.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/BackendLLMServiceTests.swift:14-120` — three additional integration tests using the same helper.
- See also: gotcha `gotchas/hummingbird-test-live-vs-router-transport.md`, pattern `patterns/end-to-end-test-with-live-backend.md`.
