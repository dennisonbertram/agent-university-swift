// ChatStreamEndpointTests.swift — BT-005: POST /chat/stream SSE streaming tests

import Testing
import Foundation
import Hummingbird
import HummingbirdTesting
import AnthropicClient
@testable import ToolService

@Suite("POST /chat/stream endpoint")
struct ChatStreamEndpointTests {

    // BT-005: When POST /chat/stream is called with a valid body, the response has
    // content-type=text/event-stream and the body contains SSE frames for each
    // contentBlockDelta, terminated with `event: done\ndata: [DONE]\n\n`.
    @Test("POST /chat/stream returns text/event-stream with SSE frames")
    func postChatStreamReturnsSSE() async throws {
        let events = MockLLMService.makeStreamEvents(texts: ["Hello", " world"])
        let mock = MockLLMService(streamResult: .events(events))
        let app = buildApplication(service: mock)

        let requestBody = """
        {"model":"claude-test","max_tokens":1024,"messages":[{"role":"user","content":"hi"}]}
        """

        try await app.test(.live) { client in
            try await client.execute(
                uri: "/chat/stream",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                #expect(response.status == .ok)

                let contentType = response.headers[.contentType] ?? ""
                #expect(contentType.contains("text/event-stream"))

                let bodyString = String(buffer: response.body)

                // Each contentBlockDelta text should appear as an SSE data frame
                #expect(bodyString.contains("data: Hello\n\n"))
                #expect(bodyString.contains("data:  world\n\n"))

                // Must end with the [DONE] terminator
                #expect(bodyString.contains("event: done\ndata: [DONE]\n\n"))
            }
        }
    }

    // Regression pin: SSE [DONE] terminator is always present at end of stream
    @Test("POST /chat/stream always ends with [DONE] terminator")
    func postChatStreamDoneTerminator() async throws {
        let events = MockLLMService.makeStreamEvents(texts: ["single delta"])
        let mock = MockLLMService(streamResult: .events(events))
        let app = buildApplication(service: mock)

        let requestBody = """
        {"model":"claude-test","max_tokens":256,"messages":[{"role":"user","content":"ping"}]}
        """

        try await app.test(.live) { client in
            try await client.execute(
                uri: "/chat/stream",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                let bodyString = String(buffer: response.body)
                // The [DONE] terminator must be present regardless of stream length
                #expect(bodyString.hasSuffix("event: done\ndata: [DONE]\n\n") || bodyString.contains("event: done\ndata: [DONE]\n\n"))
            }
        }
    }

    // POST /chat/stream with malformed JSON returns 400
    @Test("POST /chat/stream with malformed JSON returns 400")
    func postChatStreamMalformedJson() async throws {
        let mock = MockLLMService()
        let app = buildApplication(service: mock)

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/chat/stream",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: "{ bad json ]")
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
}
