// TestFixtures.swift — shared helpers for CapstoneTests

import AnthropicClient
import Foundation
import Hummingbird
import NIOConcurrencyHelpers
import NIOCore
import ServiceLifecycle
import ChatBackendLib
@testable import ChatCore

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

// MARK: - Live server helper for URLSession-based tests

/// Starts a real backend on a free port, waits for it to bind, runs tests, then shuts down.
/// Unlike app.test(.live) which uses a NIO test client, this uses the real URLSession path.
func withLiveBackendForURLSession(
    service: any LLMService,
    test: @escaping @Sendable (_ port: Int) async throws -> Void
) async throws {
    // Use a NIOLockedValueBox to capture the port from onServerRunning callback
    let portBox = NIOLockedValueBox<Int?>(nil)
    let portReady = AsyncStream<Int>.makeStream()

    let app = Application(
        router: buildRouter(service: service),
        configuration: .init(
            address: .hostname("127.0.0.1", port: 0),
            serverName: "chat-backend-test"
        ),
        onServerRunning: { @Sendable channel async in
            let port = channel.localAddress!.port!
            portBox.withLockedValue { $0 = port }
            portReady.continuation.yield(port)
        }
    )

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await app.runService()
        }

        // Wait for port
        var port: Int? = nil
        for await p in portReady.stream {
            port = p
            break
        }
        portReady.continuation.finish()

        guard let livePort = port else {
            group.cancelAll()
            return
        }

        // Run the test
        do {
            try await test(livePort)
        } catch {
            group.cancelAll()
            throw error
        }
        group.cancelAll()
    }
}
