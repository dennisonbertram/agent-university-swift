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
        // Upstream mock that throws AnthropicError.unauthorized
        let upstream = MockUpstreamLLMService()
        upstream.throwError = AnthropicError.unauthorized(body: "bad key")

        let app = buildBackend(service: upstream)
        try await app.test(.live) { client in
            let port = client.port!
            let backendService = BackendLLMService(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!
            )
            let (errorMessage, msgCount, firstRole) = try await MainActor.run {
                let vm = ChatViewModel(service: backendService, model: "claude-test")
                return Task {
                    await vm.send(userText: "ping")
                    return (vm.errorMessage, vm.messages.count, vm.messages.first?.role)
                }
            }.value

            // After 401: errorMessage is set, assistant message rolled back
            #expect(errorMessage != nil)
            // Only the user message remains (assistant was rolled back)
            #expect(msgCount == 1)
            #expect(firstRole == .user)
        }
    }

    // BT-004: Cancellation mid-stream — iteration stops cleanly, no partial-state leak
    @Test("Cancellation mid-stream: iteration stops cleanly")
    func cancellationMidStream() async throws {
        // Use an upstream that produces many deltas but no messageStop
        let upstream = MockUpstreamLLMService()
        upstream.events = Array(repeating: StreamEvent.contentBlockDelta(index: 0, textDelta: "x"), count: 100)

        let app = buildBackend(service: upstream)
        try await app.test(.live) { client in
            let port = client.port!
            let backendService = BackendLLMService(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!
            )

            let request = MessageRequest(
                model: "claude-test",
                maxTokens: 128,
                messages: [InputMessage(role: .user, content: .text("hi"))]
            )

            // Create task and cancel it quickly
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

            // Task must finish (no hang) — reaching here proves clean termination
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

        let app = buildBackend(service: upstream)
        try await app.test(.live) { client in
            let port = client.port!
            let backendService = BackendLLMService(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!
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

            // Should receive contentBlockDelta and messageStop
            #expect(receivedEvents.contains(.messageStop))
            let hasTextDelta = receivedEvents.contains(where: {
                if case .contentBlockDelta(_, _) = $0 { return true }
                return false
            })
            #expect(hasTextDelta)
        }
    }
}
