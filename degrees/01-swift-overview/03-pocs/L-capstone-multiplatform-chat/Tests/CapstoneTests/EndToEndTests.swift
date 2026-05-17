// EndToEndTests.swift — BT-001, BT-002: full ViewModel ↔ Backend ↔ MockUpstream chain

import Testing
import Hummingbird
import HummingbirdTesting
import Foundation
import AnthropicClient
import ChatBackendLib
@testable import ChatCore

@Suite("Capstone End-to-End")
struct EndToEndTests {

    // BT-001: Full streaming chain — vm.send → backend SSE → ChatViewModel state
    @Test("ViewModel -> Backend -> Upstream: full streaming chain")
    func fullChain() async throws {
        let upstream = MockUpstreamLLMService()
        upstream.events = [
            .messageStart(messageId: "m1"),
            .contentBlockDelta(index: 0, textDelta: "Hello"),
            .contentBlockDelta(index: 0, textDelta: " world"),
            .messageStop
        ]

        let app = buildBackend(service: upstream)
        try await app.test(.live) { client in
            let port = client.port!
            let backendService = BackendLLMService(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!
            )
            // Create and interact with MainActor-bound vm on the MainActor
            let result = try await MainActor.run {
                let vm = ChatViewModel(
                    service: backendService,
                    model: "claude-test",
                    system: "be brief"
                )
                return Task {
                    await vm.send(userText: "hi")
                    return (
                        messages: vm.messages,
                        isStreaming: vm.isStreaming,
                        captureCount: upstream.capturedRequests.count
                    )
                }
            }.value

            // Two messages: user + assistant
            #expect(result.messages.count == 2)
            if result.messages.count >= 1 {
                #expect(result.messages[0].role == .user)
                #expect(result.messages[0].text == "hi")
            }
            if result.messages.count >= 2 {
                #expect(result.messages[1].role == .assistant)
                #expect(result.messages[1].text == "Hello world")
            }
            #expect(result.isStreaming == false)
            // Backend received exactly one request
            #expect(result.captureCount == 1)
        }
    }

    // BT-002: System prompt survives the round-trip
    @Test("System prompt round-trip: system field captured by upstream MockLLMService")
    func systemPromptRoundTrip() async throws {
        let upstream = MockUpstreamLLMService()
        upstream.events = [
            .contentBlockDelta(index: 0, textDelta: "brief"),
            .messageStop
        ]

        let app = buildBackend(service: upstream)
        try await app.test(.live) { client in
            let port = client.port!
            let backendService = BackendLLMService(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!
            )
            let capturedSystem = try await MainActor.run {
                let vm = ChatViewModel(
                    service: backendService,
                    model: "claude-test",
                    system: "be brief"
                )
                return Task {
                    await vm.send(userText: "hello")
                    return upstream.capturedRequests.first?.system
                }
            }.value

            // The upstream mock should have captured the system prompt
            #expect(capturedSystem == "be brief")
        }
    }
}
