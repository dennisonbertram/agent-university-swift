// ErrorMappingTests.swift — BT-003, BT-004: AnthropicError → HTTP status mapping

import Testing
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import AnthropicClient
@testable import ToolService

@Suite("Error mapping — POST /chat")
struct ErrorMappingTests {

    // BT-003: When POST /chat throws AnthropicError.unauthorized, response is 401
    // with JSON body {"error":"unauthorized","detail":"..."}
    @Test("POST /chat returns 401 when LLMService throws unauthorized")
    func postChatUnauthorized() async throws {
        let mock = MockLLMService(
            sendResult: .failure(AnthropicError.unauthorized(body: "invalid api key"))
        )
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
                #expect(response.status == .unauthorized)
                let bodyString = String(buffer: response.body)
                #expect(bodyString.contains("\"error\""))
                #expect(bodyString.contains("unauthorized"))
                #expect(bodyString.contains("\"detail\""))
            }
        }
    }

    // BT-004: When POST /chat throws AnthropicError.rateLimited(retryAfter:"30",...),
    // response is 429 with header Retry-After: 30 and a JSON error body.
    @Test("POST /chat returns 429 with Retry-After header when LLMService throws rateLimited")
    func postChatRateLimited() async throws {
        let mock = MockLLMService(
            sendResult: .failure(AnthropicError.rateLimited(retryAfter: "30", body: "too many requests"))
        )
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
                #expect(response.status == .tooManyRequests)
                let retryAfter = response.headers[HTTPField.Name("Retry-After")!]
                #expect(retryAfter == "30")
                let bodyString = String(buffer: response.body)
                #expect(bodyString.contains("error"))
            }
        }
    }

    // Additional: POST /chat throws badRequest → 400
    @Test("POST /chat returns 400 when LLMService throws badRequest")
    func postChatBadRequest() async throws {
        let mock = MockLLMService(
            sendResult: .failure(AnthropicError.badRequest(body: "invalid parameter"))
        )
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
                #expect(response.status == .badRequest)
            }
        }
    }

    // Additional: POST /chat throws serverError(500,...) → 502 Bad Gateway
    @Test("POST /chat returns 502 when LLMService throws serverError")
    func postChatServerError() async throws {
        let mock = MockLLMService(
            sendResult: .failure(AnthropicError.serverError(status: 500, body: "internal server error"))
        )
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
                #expect(response.status == .badGateway)
            }
        }
    }
}
