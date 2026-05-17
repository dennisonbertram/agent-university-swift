// RegressionTests.swift — regression pins for capstone
// Additional pins added in commit 3 (UI-free viewmodel + [DONE] terminator)

import Testing
import Hummingbird
import HummingbirdTesting
import Foundation
import AnthropicClient
import ChatBackendLib
@testable import ChatCore

@Suite("Capstone Regression Pins")
struct RegressionTests {

    // REGRESSION-001: SSE [DONE] terminator always ends the stream on /chat/stream
    @Test("REGRESSION-001: backend /chat/stream always emits [DONE] terminator")
    func chatStreamAlwaysEmitsDoneTerminator() async throws {
        let upstream = MockUpstreamLLMService()
        upstream.events = [
            .contentBlockDelta(index: 0, textDelta: "answer"),
            .messageStop
        ]

        let app = buildBackend(service: upstream)
        try await app.test(.live) { client in
            let requestBody = TestFixtures.jsonBody(userText: "ping")
            try await client.execute(
                uri: "/chat/stream",
                method: .post,
                headers: [.contentType: "application/json"],
                body: ByteBuffer(string: requestBody)
            ) { response in
                #expect(response.status == .ok)
                let bodyString = String(buffer: response.body)
                #expect(bodyString.contains("event: done\ndata: [DONE]\n\n"),
                    "SSE stream must end with [DONE] terminator")
            }
        }
    }
}
