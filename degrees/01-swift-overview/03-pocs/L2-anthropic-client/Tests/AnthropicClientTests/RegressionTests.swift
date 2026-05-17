// RegressionTests.swift — regression tests that pin critical behaviors

import Testing
import Foundation
@testable import AnthropicClient

// MARK: - Regression 1: Auth headers must always be present
//
// If a future refactor moves header construction or renames constants,
// these tests catch the regression before it ships.

@Suite("Regression: Auth Headers")
struct AuthHeaderRegressionTests {

    private let successResponseJSON = """
    {
      "id": "msg_regression_test",
      "type": "message",
      "role": "assistant",
      "model": "claude-sonnet-4-5",
      "content": [{ "type": "text", "text": "ok" }],
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "usage": { "input_tokens": 5, "output_tokens": 3 }
    }
    """

    @Test("anthropic-version header is exactly '2023-06-01' on every send call")
    func anthropicVersionHeaderIsPinned() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: successResponseJSON, statusCode: 200)
        let client = AnthropicClient(apiKey: "sk-test-regression", transport: mock)
        let req = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 256,
            messages: [InputMessage(role: .user, content: .text("ping"))]
        )
        _ = try await client.send(req)
        let captured = mock.capturedRequests[0]
        // This test fails if anthropic-version is dropped or changed
        #expect(captured.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    }

    @Test("x-api-key header is set to the apiKey passed at init on every send call")
    func xApiKeyHeaderMatchesInit() async throws {
        let apiKey = "sk-ant-regression-key-xyz"
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: successResponseJSON, statusCode: 200)
        let client = AnthropicClient(apiKey: apiKey, transport: mock)
        let req = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 256,
            messages: [InputMessage(role: .user, content: .text("ping"))]
        )
        _ = try await client.send(req)
        let captured = mock.capturedRequests[0]
        // This test fails if the x-api-key header is dropped or uses a wrong value
        #expect(captured.value(forHTTPHeaderField: "x-api-key") == apiKey)
    }

    @Test("Both required auth headers present in a single request")
    func bothAuthHeadersPresentTogether() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: successResponseJSON, statusCode: 200)
        let client = AnthropicClient(apiKey: "sk-test-both-headers", transport: mock)
        let req = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 256,
            messages: [InputMessage(role: .user, content: .text("ping"))]
        )
        _ = try await client.send(req)
        let captured = mock.capturedRequests[0]
        let apiKeyHeader = captured.value(forHTTPHeaderField: "x-api-key")
        let versionHeader = captured.value(forHTTPHeaderField: "anthropic-version")
        // If EITHER header is missing, this test fails — covers the combined regression
        #expect(apiKeyHeader != nil && !apiKeyHeader!.isEmpty)
        #expect(versionHeader == "2023-06-01")
    }
}

// MARK: - Regression 2: SSE 'data: ' space handling
//
// The SSE spec says the value of a field is the text AFTER the first ':' and
// optional single space. If the parser strips more than one leading space,
// text content starting with a space (e.g., assistant turn-continuations)
// will be silently corrupted.

@Suite("Regression: SSE space handling")
struct SSESpaceRegressionTests {

    @Test("data: with one leading space yields text verbatim — space is separator not content")
    func dataFieldSingleSpaceIsStripped() async throws {
        // The SSE field is "data: <json>" — the single space after ':' is the separator.
        // The JSON payload {"text":"Hello"} must reach the parser intact.
        let sse = """
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let events = try await collectEvents(from: SSEParser.parse(bytes: byteStream))
        // If the parser eats the space AND the first char of JSON, decode fails or wrong text
        if case .contentBlockDelta(_, let text) = events[0] {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected contentBlockDelta with 'Hello', got \(events[0])")
        }
    }

    @Test("assistant text with leading space in JSON value is preserved exactly")
    func leadingSpaceInJSONPayloadPreserved() async throws {
        // The text content itself has a leading space — must not be stripped
        // (only the SSE field separator space is stripped, not the JSON value)
        let sse = """
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let events = try await collectEvents(from: SSEParser.parse(bytes: byteStream))
        if case .contentBlockDelta(_, let text) = events[0] {
            // Leading space inside the JSON string must be preserved
            #expect(text == " world")
        } else {
            Issue.record("Expected contentBlockDelta with ' world', got \(events[0])")
        }
    }

    @Test("data: with no space after colon is also handled (spec allows omitting the space)")
    func dataFieldNoSpaceWorks() async throws {
        // Some servers omit the space: "data:{...}" — parser must handle both forms
        let sse = """
        event: content_block_delta\r
        data:{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"NoSpace"}}\r
        \r
        event: message_stop\r
        data:{"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let events = try await collectEvents(from: SSEParser.parse(bytes: byteStream))
        if case .contentBlockDelta(_, let text) = events[0] {
            #expect(text == "NoSpace")
        } else {
            Issue.record("Expected contentBlockDelta with 'NoSpace', got \(events[0])")
        }
    }
}
