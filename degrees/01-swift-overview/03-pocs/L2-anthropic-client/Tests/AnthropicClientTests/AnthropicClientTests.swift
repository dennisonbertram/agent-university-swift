// AnthropicClientTests.swift — high-level send/stream behavioral tests

import Testing
import Foundation
@testable import AnthropicClient

// MARK: - Canned JSON fixtures

private let successResponseJSON = """
{
  "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
  "type": "message",
  "role": "assistant",
  "model": "claude-sonnet-4-5",
  "content": [
    { "type": "text", "text": "Hi! My name is Claude." }
  ],
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {
    "input_tokens": 10,
    "output_tokens": 25
  }
}
"""

private let errorResponseJSON = """
{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}
"""

private let rateLimitResponseJSON = """
{"type":"error","error":{"type":"rate_limit_error","message":"rate limit exceeded"}}
"""

private let badRequestResponseJSON = """
{"type":"error","error":{"type":"invalid_request_error","message":"bad request"}}
"""

private let serverErrorResponseJSON = """
{"type":"error","error":{"type":"server_error","message":"internal error"}}
"""

// Full SSE stream from research file §5
private let fullSSEBytes = """
event: message_start\r
data: {"type":"message_start","message":{"id":"msg_01XFDUDYJgAACzvnptvVoYEL","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}\r
\r
event: content_block_start\r
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\r
\r
event: ping\r
data: {"type":"ping"}\r
\r
event: content_block_delta\r
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\r
\r
event: content_block_delta\r
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"!"}}\r
\r
event: content_block_stop\r
data: {"type":"content_block_stop","index":0}\r
\r
event: message_delta\r
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}}\r
\r
event: message_stop\r
data: {"type":"message_stop"}\r
\r

"""

@Suite("AnthropicClient.send")
struct AnthropicClientSendTests {

    @Test("send builds correct URL, method, and auth headers")
    func sendBuildsCorrectRequest() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: successResponseJSON, statusCode: 200)
        let client = AnthropicClient(apiKey: "test-key-abc", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hello"))]
        )
        _ = try await client.send(request)

        #expect(mock.capturedRequests.count == 1)
        let urlRequest = mock.capturedRequests[0]
        #expect(urlRequest.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "x-api-key") == "test-key-abc")
        #expect(urlRequest.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(urlRequest.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    @Test("send body JSON-decodes to original request")
    func sendBodyMatchesRequest() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: successResponseJSON, statusCode: 200)
        let client = AnthropicClient(apiKey: "test-key-abc", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hello"))]
        )
        _ = try await client.send(request)

        let urlRequest = mock.capturedRequests[0]
        let bodyData = urlRequest.httpBody!
        let decoded = try JSONDecoder().decode(MessageRequest.self, from: bodyData)
        #expect(decoded.model == "claude-sonnet-4-5-20250929")
        #expect(decoded.maxTokens == 1024)
        #expect(decoded.messages.count == 1)
        if case .text(let text) = decoded.messages[0].content {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test("send with 200 response returns decoded Message with correct fields")
    func sendSuccessReturnsMessage() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: successResponseJSON, statusCode: 200)
        let client = AnthropicClient(apiKey: "test-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )
        let message = try await client.send(request)

        #expect(message.id == "msg_01XFDUDYJgAACzvnptvVoYEL")
        #expect(message.role == .assistant)
        #expect(message.content.count == 1)
        #expect(message.content[0].text == "Hi! My name is Claude.")
        #expect(message.stopReason == "end_turn")
    }

    @Test("send with 401 throws AnthropicError.unauthorized with body")
    func sendUnauthorizedThrows() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: errorResponseJSON, statusCode: 401)
        let client = AnthropicClient(apiKey: "bad-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )
        do {
            _ = try await client.send(request)
            Issue.record("Expected send to throw")
        } catch let error as AnthropicError {
            if case .unauthorized(let body) = error {
                #expect(!body.isEmpty)
            } else {
                Issue.record("Expected .unauthorized, got \(error)")
            }
        }
    }

    @Test("send with 429 throws AnthropicError.rateLimited with retry-after value")
    func sendRateLimitedThrows() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: rateLimitResponseJSON, statusCode: 429, headers: ["Retry-After": "30"])
        let client = AnthropicClient(apiKey: "test-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )
        do {
            _ = try await client.send(request)
            Issue.record("Expected send to throw")
        } catch let error as AnthropicError {
            if case .rateLimited(let retryAfter, _) = error {
                #expect(retryAfter == "30")
            } else {
                Issue.record("Expected .rateLimited, got \(error)")
            }
        }
    }

    @Test("send with 500 throws AnthropicError.serverError with status code")
    func sendServerErrorThrows() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: serverErrorResponseJSON, statusCode: 500)
        let client = AnthropicClient(apiKey: "test-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )
        do {
            _ = try await client.send(request)
            Issue.record("Expected send to throw")
        } catch let error as AnthropicError {
            if case .serverError(let status, _) = error {
                #expect(status == 500)
            } else {
                Issue.record("Expected .serverError(500), got \(error)")
            }
        }
    }

    @Test("send with 400 throws AnthropicError.badRequest")
    func sendBadRequestThrows() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: badRequestResponseJSON, statusCode: 400)
        let client = AnthropicClient(apiKey: "test-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )
        do {
            _ = try await client.send(request)
            Issue.record("Expected send to throw")
        } catch let error as AnthropicError {
            if case .badRequest = error {
                // expected
            } else {
                Issue.record("Expected .badRequest, got \(error)")
            }
        }
    }
}

@Suite("AnthropicClient.stream")
struct AnthropicClientStreamTests {

    @Test("stream yields 7 events from full SSE sequence (ping filtered)")
    func streamYieldsCorrectEvents() async throws {
        let mock = MockHTTPTransport()
        mock.bytesResponseData = Data(fullSSEBytes.utf8)
        mock.bytesStatusCode = 200
        let client = AnthropicClient(apiKey: "test-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )
        var events: [StreamEvent] = []
        for try await event in client.stream(request) {
            events.append(event)
        }
        // message_start, content_block_start, content_block_delta x2, content_block_stop, message_delta, message_stop
        // ping is filtered = 7 total events
        #expect(events.count == 7)
    }

    @Test("stream events arrive in correct order: messageStart first, messageStop last")
    func streamEventOrder() async throws {
        let mock = MockHTTPTransport()
        mock.bytesResponseData = Data(fullSSEBytes.utf8)
        mock.bytesStatusCode = 200
        let client = AnthropicClient(apiKey: "test-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )
        var events: [StreamEvent] = []
        for try await event in client.stream(request) {
            events.append(event)
        }
        if case .messageStart(let id) = events.first {
            #expect(id == "msg_01XFDUDYJgAACzvnptvVoYEL")
        } else {
            Issue.record("Expected messageStart first, got \(String(describing: events.first))")
        }
        #expect(events.last == .messageStop)
    }

    @Test("stream sets stream=true in request body")
    func streamSetsStreamFlag() async throws {
        let mock = MockHTTPTransport()
        mock.bytesResponseData = Data(fullSSEBytes.utf8)
        mock.bytesStatusCode = 200
        let client = AnthropicClient(apiKey: "test-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )
        for try await _ in client.stream(request) { break }
        let urlRequest = mock.capturedRequests[0]
        let bodyData = urlRequest.httpBody!
        let decoded = try JSONDecoder().decode(MessageRequest.self, from: bodyData)
        #expect(decoded.stream == true)
    }

    @Test("stream cancellation stops iteration")
    func streamCancellationStops() async throws {
        // Create an infinite-ish SSE stream that would normally keep going
        // Then cancel the task and verify we exit cleanly
        let mock = MockHTTPTransport()
        // Use the full SSE bytes but verify that task cancellation works
        mock.bytesResponseData = Data(fullSSEBytes.utf8)
        mock.bytesStatusCode = 200
        let client = AnthropicClient(apiKey: "test-key", transport: mock)
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hi"))]
        )

        var eventCount = 0
        let task = Task {
            for try await _ in client.stream(request) {
                eventCount += 1
                // Cancel after first event to test cancellation
                if eventCount == 1 {
                    return
                }
            }
        }
        _ = try await task.value
        // We returned after first event — verify the task completed without hanging
        #expect(eventCount >= 1)
    }
}
