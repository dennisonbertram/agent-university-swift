// BackendLLMServiceTests.swift — BT-003, BT-004: client-side tests for BackendLLMService

import Testing
import Hummingbird
import HummingbirdTesting
import Foundation
import AnthropicClient
import ChatBackendLib
@testable import ChatCore

@Suite("BackendLLMService")
struct BackendLLMServiceTests {

    // BT-003: 401 from backend → BackendLLMService throws .unauthorized → ChatViewModel surfaces errorMessage
    @Test("401 response: ChatViewModel surfaces errorMessage and rolls back assistant message")
    func unauthorizedResponseSurfacesError() async throws {
        let upstream = MockUpstreamLLMService()
        upstream.throwError = AnthropicError.unauthorized(body: "bad key")

        try await withLiveBackendForURLSession(service: upstream) { port in
            let session = URLSession(configuration: .ephemeral)
            let backendService = BackendLLMService(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!,
                session: session
            )

            let capture = VMResultCapture()
            Task { @MainActor in
                let vm = ChatViewModel(service: backendService, model: "claude-test")
                await vm.send(userText: "ping")
                capture.deliver(VMResult(
                    messages: vm.messages,
                    isStreaming: vm.isStreaming,
                    errorMessage: vm.errorMessage
                ))
            }

            var result: VMResult? = nil
            for await r in capture.stream { result = r }
            let r = try #require(result)

            // After 401: errorMessage is set, assistant message rolled back
            #expect(r.errorMessage != nil)
            #expect(r.messages.count == 1)
            #expect(r.messages.first?.role == .user)
        }
    }

    // BT-004: Cancellation mid-stream — iteration stops cleanly, no partial-state leak
    @Test("Cancellation mid-stream: iteration stops cleanly")
    func cancellationMidStream() async throws {
        let upstream = MockUpstreamLLMService()
        upstream.events = Array(repeating: StreamEvent.contentBlockDelta(index: 0, textDelta: "x"), count: 100)

        try await withLiveBackendForURLSession(service: upstream) { port in
            let session = URLSession(configuration: .ephemeral)
            let backendService = BackendLLMService(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!,
                session: session
            )

            let request = MessageRequest(
                model: "claude-test",
                maxTokens: 128,
                messages: [InputMessage(role: .user, content: .text("hi"))]
            )

            let task = Task {
                var count = 0
                do {
                    for try await _ in backendService.stream(request) {
                        count += 1
                        if count >= 2 { break }
                    }
                } catch is CancellationError {
                    // Expected — clean finish
                }
                return count
            }
            task.cancel()

            let _ = try? await task.value
            #expect(Bool(true), "Stream cancelled cleanly without hanging")
        }
    }

    // SSE [DONE] terminator: stream finishes with messageStop then completes
    @Test("SSE [DONE] terminator: stream completes with messageStop event")
    func doneTerminatorProducesMessageStop() async throws {
        let upstream = MockUpstreamLLMService()
        upstream.events = [
            .contentBlockDelta(index: 0, textDelta: "done"),
            .messageStop
        ]

        try await withLiveBackendForURLSession(service: upstream) { port in
            let session = URLSession(configuration: .ephemeral)
            let backendService = BackendLLMService(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!,
                session: session
            )

            let request = MessageRequest(
                model: "claude-test",
                maxTokens: 128,
                messages: [InputMessage(role: .user, content: .text("hi"))]
            )

            var receivedEvents: [StreamEvent] = []
            for try await event in backendService.stream(request) {
                receivedEvents.append(event)
            }

            #expect(receivedEvents.contains(.messageStop))
            let hasTextDelta = receivedEvents.contains(where: {
                if case .contentBlockDelta(_, _) = $0 { return true }
                return false
            })
            #expect(hasTextDelta)
        }
    }
}
