// RegressionTests.swift — regression coverage for TASK-L6-001
// Two regression tests pinning: multi-turn history growth and UI-framework-free view model.

import Testing
import Foundation
import AnthropicClient
@testable import ChatCoreShared

@MainActor
@Suite("ChatCoreShared Regression Tests")
struct ChatCoreSharedRegressionTests {

    // MARK: - REGRESSION-001: Multi-turn history grows correctly
    //
    // After two send() calls, the MessageRequest captured on the SECOND call must contain
    // all three prior messages: [user("hi"), assistant(<prev>), user("again")].
    // count == 3 pins that the conversation accumulates across turns.
    // If history were cleared between sends, count would be 1 and this test fails.

    @Test("REGRESSION-001: after two send() calls, second request.messages.count == 3")
    func multiTurnHistoryGrowsCorrectly() async {
        let mock = MockLLMService()

        // First turn
        mock.events = [
            .contentBlockDelta(index: 0, textDelta: "I'm fine"),
            .messageStop
        ]
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "hi")

        // Second turn
        mock.events = [
            .contentBlockDelta(index: 0, textDelta: "Sure"),
            .messageStop
        ]
        await vm.send(userText: "again")

        #expect(mock.capturedRequests.count == 2,
                "Two requests should be captured across two turns")

        let secondRequest = mock.capturedRequests[1]
        // Second request must carry: user("hi"), assistant("I'm fine"), user("again")
        #expect(secondRequest.messages.count == 3,
                "Second MessageRequest must have 3 messages (prior user + prior assistant + new user); got \(secondRequest.messages.count)")
        #expect(secondRequest.messages[0].role == .user,
                "Message[0] must be user")
        #expect(secondRequest.messages[0].content == .text("hi"),
                "Message[0] content must be 'hi'")
        #expect(secondRequest.messages[1].role == .assistant,
                "Message[1] must be assistant")
        #expect(secondRequest.messages[1].content == .text("I'm fine"),
                "Message[1] content must be the accumulated assistant response")
        #expect(secondRequest.messages[2].role == .user,
                "Message[2] must be user")
        #expect(secondRequest.messages[2].content == .text("again"),
                "Message[2] content must be 'again'")
    }

    // MARK: - REGRESSION-002: ChatViewModel.swift does NOT import SwiftUI
    //
    // The view model must remain UI-framework-free so it can be consumed by non-SwiftUI
    // contexts (CLI tools, test harnesses, future KMM ports).
    // This test reads the source file and asserts "import SwiftUI" is absent.
    // If someone accidentally adds `import SwiftUI`, this test catches it immediately.

    @Test("REGRESSION-002: ChatViewModel.swift contains no 'import SwiftUI'")
    func chatViewModelHasNoSwiftUIImport() throws {
        // Locate ChatViewModel.swift relative to the package root.
        // The test bundle path gives us a clue; we walk up to find Sources/ChatCoreShared/.
        let fileManager = FileManager.default

        // Strategy: search from the current working directory upward for the file.
        // swift test sets cwd to the package root, so we can use a relative path here.
        let candidates = [
            // Absolute path for CI/CD reliability
            "/Users/dennison/develop/agent-university/swift/degrees/01-swift-overview/03-pocs/L6-swiftui-ios-app/Sources/ChatCoreShared/ChatViewModel.swift",
            // Relative fallback (works when cwd == package root)
            "Sources/ChatCoreShared/ChatViewModel.swift"
        ]

        var sourceContent: String? = nil
        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate),
               let content = try? String(contentsOfFile: candidate, encoding: .utf8) {
                sourceContent = content
                break
            }
        }

        guard let content = sourceContent else {
            // If we can't find the file, skip gracefully with a descriptive message.
            // This prevents false failures in CI environments with different layouts.
            #expect(Bool(false), "Could not locate ChatViewModel.swift at expected paths — verify test setup")
            return
        }

        let lines = content.components(separatedBy: "\n")
        let swiftUIImportLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Exact match for import statements (not comments, not partial matches)
            return trimmed == "import SwiftUI" || trimmed.hasPrefix("import SwiftUI ")
        }

        #expect(swiftUIImportLines.isEmpty,
                "ChatViewModel.swift must not import SwiftUI; found: \(swiftUIImportLines). The view model must remain UI-framework-free for cross-platform portability.")
    }
}
