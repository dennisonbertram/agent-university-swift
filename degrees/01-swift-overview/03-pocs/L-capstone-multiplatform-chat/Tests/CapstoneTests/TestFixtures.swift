// TestFixtures.swift — shared helpers for CapstoneTests

import AnthropicClient
import Foundation

// MARK: - Canned test data

enum TestFixtures {
    static let helloWorldEvents: [StreamEvent] = [
        .messageStart(messageId: "m1"),
        .contentBlockDelta(index: 0, textDelta: "Hello"),
        .contentBlockDelta(index: 0, textDelta: " world"),
        .messageStop
    ]

    static let singleDeltaEvents: [StreamEvent] = [
        .messageStart(messageId: "m2"),
        .contentBlockDelta(index: 0, textDelta: "pong"),
        .messageStop
    ]

    static let simpleRequest = MessageRequest(
        model: "claude-test",
        maxTokens: 128,
        messages: [InputMessage(role: .user, content: .text("hi"))],
        system: nil
    )

    static func jsonBody(
        model: String = "claude-test",
        maxTokens: Int = 128,
        userText: String = "hi",
        system: String? = nil
    ) -> String {
        var parts = [
            "\"model\":\"\(model)\"",
            "\"max_tokens\":\(maxTokens)",
            "\"messages\":[{\"role\":\"user\",\"content\":\"\(userText)\"}]"
        ]
        if let sys = system {
            parts.append("\"system\":\"\(sys)\"")
        }
        return "{\(parts.joined(separator: ","))}"
    }
}
