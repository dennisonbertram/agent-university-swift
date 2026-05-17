// EndToEndTests.swift — BT-001, BT-002: full ViewModel ↔ Backend ↔ MockUpstream chain
//
// Uses withLiveBackendForURLSession so URLSession-based BackendLLMService can connect
// to the Hummingbird backend (URLSession and the HummingbirdTesting NIO client use
// different transport stacks in swift test; the withLiveBackendForURLSession helper
// starts a real server that URLSession can connect to).

import Testing
import Hummingbird
import HummingbirdTesting
import Foundation
import AnthropicClient
import ChatBackendLib
@testable import ChatCore

// MARK: - Result type

struct VMResult: Sendable {
    let messages: [ChatMessage]
    let isStreaming: Bool
    let errorMessage: String?
}

// MARK: - Bridge class

final class VMResultCapture: @unchecked Sendable {
    private let continuation: AsyncStream<VMResult>.Continuation
    let stream: AsyncStream<VMResult>

    init() {
        var cont: AsyncStream<VMResult>.Continuation!
        stream = AsyncStream<VMResult> { cont = $0 }
        continuation = cont
    }

    func deliver(_ result: VMResult) {
        continuation.yield(result)
        continuation.finish()
    }
}

// MARK: - Tests

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

        try await withLiveBackendForURLSession(service: upstream) { port in
            let backendURL = URL(string: "http://127.0.0.1:\(port)")!
            let session = URLSession(configuration: .ephemeral)
            let backendService = BackendLLMService(baseURL: backendURL, session: session)

            let capture = VMResultCapture()
            Task { @MainActor in
                let vm = ChatViewModel(
                    service: backendService,
                    model: "claude-test",
                    system: "be brief"
                )
                await vm.send(userText: "hi")
                capture.deliver(VMResult(
                    messages: vm.messages,
                    isStreaming: vm.isStreaming,
                    errorMessage: vm.errorMessage
                ))
            }

            var result: VMResult? = nil
            for await r in capture.stream { result = r }

            let captureCount = upstream.capturedRequests.count
            let r = try #require(result)

            // Two messages: user + assistant
            #expect(r.messages.count == 2)
            if r.messages.count >= 1 {
                #expect(r.messages[0].role == .user)
                #expect(r.messages[0].text == "hi")
            }
            if r.messages.count >= 2 {
                #expect(r.messages[1].role == .assistant)
                #expect(r.messages[1].text == "Hello world")
            }
            #expect(r.isStreaming == false)
            #expect(captureCount == 1)
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

        try await withLiveBackendForURLSession(service: upstream) { port in
            let backendURL = URL(string: "http://127.0.0.1:\(port)")!
            let session = URLSession(configuration: .ephemeral)
            let backendService = BackendLLMService(baseURL: backendURL, session: session)

            let capture = VMResultCapture()
            Task { @MainActor in
                let vm = ChatViewModel(
                    service: backendService,
                    model: "claude-test",
                    system: "be brief"
                )
                await vm.send(userText: "hello")
                capture.deliver(VMResult(
                    messages: vm.messages,
                    isStreaming: vm.isStreaming,
                    errorMessage: vm.errorMessage
                ))
            }

            for await _ in capture.stream { break }

            let capturedSystem = upstream.capturedRequests.first?.system
            #expect(capturedSystem == "be brief")
        }
    }
}
