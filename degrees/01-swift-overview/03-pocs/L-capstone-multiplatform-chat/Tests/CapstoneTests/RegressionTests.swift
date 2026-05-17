// RegressionTests.swift — regression pins for capstone
//
// REGRESSION-001: SSE [DONE] terminator always ends /chat/stream
// REGRESSION-002: ChatViewModel.swift does NOT import SwiftUI (cross-platform pin)

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
    // If the backend router drops the [DONE] terminator, this test will fail.
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
                    "SSE stream must end with [DONE] terminator — if this fails, the terminator was dropped")
            }
        }
    }

    // REGRESSION-002: ChatViewModel.swift must NOT contain 'import SwiftUI'.
    // This ensures the view model remains cross-platform (usable on Linux, iOS, macOS, etc.)
    // without pulling in UIKit/AppKit through SwiftUI.
    // If someone adds 'import SwiftUI' to ChatViewModel.swift, this test will fail.
    @Test("REGRESSION-002: ChatViewModel.swift has no import SwiftUI")
    func chatViewModelHasNoSwiftUIImport() throws {
        // Read the ChatViewModel source file and verify it does not contain 'import SwiftUI'
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CapstoneTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // L-capstone-multiplatform-chat/
        let vmPath = packageRoot
            .appendingPathComponent("Sources/ChatCore/ChatViewModel.swift")
        let source = try String(contentsOf: vmPath, encoding: .utf8)
        // Check each line: only flag a line that is an actual import statement
        // (not a comment), i.e. the line starts with "import SwiftUI" (ignoring leading spaces)
        let hasSwiftUIImport = source.components(separatedBy: "\n").contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("import SwiftUI")
        }
        #expect(
            !hasSwiftUIImport,
            "ChatViewModel.swift must not import SwiftUI — this breaks cross-platform portability"
        )
    }
}
