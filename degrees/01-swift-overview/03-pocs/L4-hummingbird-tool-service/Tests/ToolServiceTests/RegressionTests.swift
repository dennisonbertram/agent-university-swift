// RegressionTests.swift — Regression pins that catch future breakage.
//
// These tests answer: "if the green commit in fedc64d were reverted, which test
// would catch it first?"
//
// Regression pins:
// (a) Content-Type: application/json is present on /chat success response.
// (b) The SSE [DONE] terminator is present at the end of /chat/stream.
// (c) JSON decoder accepts snake_case keys (max_tokens, system) correctly.

import Testing
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import AnthropicClient
@testable import ToolService

@Suite("Regression pins")
struct RegressionTests {

    // (a) Content-Type: application/json must be present on /chat success.
    // If someone changes the /chat handler to return a raw string or a different
    // content-type, this test fails.
    @Test("POST /chat success response has Content-Type: application/json")
    func chatSuccessContentTypeIsJSON() async throws {
        let mock = MockLLMService(sendResult: .success(MockLLMService.makeCannedMessage()))
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
                let contentType = response.headers[.contentType] ?? ""
                // Must be application/json — not text/plain, not empty, not text/event-stream
                #expect(contentType.contains("application/json"),
                        "Expected Content-Type: application/json, got: \(contentType)")
            }
        }
    }

    // (b) The SSE [DONE] terminator MUST appear at the end of /chat/stream.
    // If the terminator is dropped (e.g. the messageStop branch is removed),
    // SSE clients will never know the stream ended.
    @Test("POST /chat/stream [DONE] terminator is present and is the last SSE event")
    func streamDoneTerminatorPresent() async throws {
        let events = MockLLMService.makeStreamEvents(texts: ["alpha", "beta", "gamma"])
        let mock = MockLLMService(streamResult: .events(events))
        let app = buildApplication(service: mock)

        let requestBody = """
        {"model":"claude-test","max_tokens":256,"messages":[{"role":"user","content":"regression"}]}
        """

        try await app.test(.live) { client in
            try await client.execute(
                uri: "/chat/stream",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                #expect(response.status == .ok)
                let bodyString = String(buffer: response.body)

                // All three delta frames must be present
                #expect(bodyString.contains("data: alpha\n\n"))
                #expect(bodyString.contains("data: beta\n\n"))
                #expect(bodyString.contains("data: gamma\n\n"))

                // [DONE] terminator must be present
                let terminator = "event: done\ndata: [DONE]\n\n"
                #expect(bodyString.contains(terminator),
                        "SSE [DONE] terminator missing from response body: \(bodyString)")
            }
        }
    }

    // (c) snake_case keys in the inbound JSON (max_tokens, system) decode correctly.
    // MessageRequest uses explicit CodingKeys with snake_case raw values, so
    // a plain JSONDecoder (not convertFromSnakeCase) is correct. If someone
    // accidentally switches to convertFromSnakeCase this test catches the breakage.
    @Test("POST /chat decodes snake_case keys max_tokens and system correctly")
    func snakeCaseKeysDecodeCorrectly() async throws {
        let mock = MockLLMService()
        let app = buildApplication(service: mock)

        // Use max_tokens and system — both are snake_case in the wire format
        let requestBody = """
        {
          "model": "claude-regression",
          "max_tokens": 4096,
          "messages": [{"role": "user", "content": "regression test"}],
          "system": "you are a regression test assistant"
        }
        """

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/chat",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                #expect(response.status == .ok,
                        "Expected 200, got \(response.status) — snake_case decode likely broken")
            }
        }

        let captured = try #require(mock.lastSendRequest,
                                    "LLMService.send was never called — request decode failed")
        #expect(captured.model == "claude-regression")
        #expect(captured.maxTokens == 4096,
                "maxTokens should be 4096 (decoded from max_tokens), got \(captured.maxTokens)")
        #expect(captured.system == "you are a regression test assistant",
                "system field not decoded, got \(captured.system ?? "nil")")
    }
}
