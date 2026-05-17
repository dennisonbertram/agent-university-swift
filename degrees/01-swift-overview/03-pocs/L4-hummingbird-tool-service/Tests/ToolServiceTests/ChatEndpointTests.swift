// ChatEndpointTests.swift — BT-002, BT-006, BT-007: POST /chat behavioral tests

import Testing
import Foundation
import Hummingbird
import HummingbirdTesting
import AnthropicClient
@testable import ToolService

@Suite("POST /chat endpoint")
struct ChatEndpointTests {

    // BT-002: When POST /chat is called with a valid body, LLMService receives the request
    // and the response body is the JSON-encoded Message returned by the service.
    @Test("POST /chat with valid body returns 200 and JSON-encoded Message")
    func postChatValidBody() async throws {
        let cannedMessage = MockLLMService.makeCannedMessage(text: "Test response")
        let mock = MockLLMService(sendResult: .success(cannedMessage))
        let app = buildApplication(service: mock)

        let requestBody = """
        {"model":"claude-test","max_tokens":1024,"messages":[{"role":"user","content":"hi"}]}
        """

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/chat",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                #expect(response.status == .ok)
                let bodyString = String(buffer: response.body)
                // Response should be JSON-encoded Message
                #expect(bodyString.contains("msg_test"))
                #expect(bodyString.contains("claude-test"))
            }
        }

        // Verify the mock captured the request with correct model and messages
        let captured = try #require(mock.lastSendRequest)
        #expect(captured.model == "claude-test")
        #expect(captured.messages.count == 1)
        #expect(captured.messages[0].role == .user)
    }

    // BT-002 (cont): LLMService receives MessageRequest with model=X and one user message
    @Test("POST /chat passes model and messages through to LLMService")
    func postChatPassesModelAndMessages() async throws {
        let mock = MockLLMService()
        let app = buildApplication(service: mock)

        let requestBody = """
        {"model":"claude-sonnet-4-5","max_tokens":512,"messages":[{"role":"user","content":"hello world"}]}
        """

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/chat",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                #expect(response.status == .ok)
            }
        }

        let captured = try #require(mock.lastSendRequest)
        #expect(captured.model == "claude-sonnet-4-5")
        #expect(captured.maxTokens == 512)
        #expect(captured.messages.count == 1)
        if case .text(let text) = captured.messages[0].content {
            #expect(text == "hello world")
        } else {
            Issue.record("Expected text content in message")
        }
    }

    // Regression pin: snake_case input (`max_tokens`) decodes correctly into MessageRequest
    @Test("POST /chat accepts snake_case JSON keys (max_tokens, system)")
    func postChatSnakeCaseKeys() async throws {
        let mock = MockLLMService()
        let app = buildApplication(service: mock)

        let requestBody = """
        {"model":"claude-test","max_tokens":2048,"messages":[{"role":"user","content":"hi"}],"system":"be brief"}
        """

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/chat",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                #expect(response.status == .ok)
            }
        }

        let captured = try #require(mock.lastSendRequest)
        #expect(captured.maxTokens == 2048)
        #expect(captured.system == "be brief")
    }

    // BT-006: When POST /chat is called with malformed JSON, response is 400.
    @Test("POST /chat with malformed JSON returns 400")
    func postChatMalformedJson() async throws {
        let mock = MockLLMService()
        let app = buildApplication(service: mock)

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/chat",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: "{not valid json{{")
            ) { response in
                #expect(response.status == .badRequest)
                let bodyString = String(buffer: response.body)
                #expect(bodyString.contains("error"))
            }
        }
    }

    // BT-007: When POST /chat is called with no `messages` field, response is 400.
    @Test("POST /chat with missing messages field returns 400")
    func postChatMissingMessages() async throws {
        let mock = MockLLMService()
        let app = buildApplication(service: mock)

        let requestBody = """
        {"model":"claude-test","max_tokens":1024}
        """

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/chat",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
}
