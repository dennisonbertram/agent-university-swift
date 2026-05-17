// MockLLMService.swift — Test double for LLMService.
//
// Provides canned Message responses, canned [StreamEvent] sequences,
// and error injection for both `send` and `stream`.

import AnthropicClient
@testable import ToolService

/// A canned response or error for `send(_:)`.
enum MockSendResult {
    case success(Message)
    case failure(Error)
}

/// A canned result for `stream(_:)`.
enum MockStreamResult {
    case events([StreamEvent])
    case failure(Error)
}

/// Thread-safe mock that captures the last `MessageRequest` sent to it.
final class MockLLMService: LLMService, @unchecked Sendable {

    // MARK: - Configuration

    var sendResult: MockSendResult
    var streamResult: MockStreamResult

    /// The last request passed to `send(_:)`.
    private(set) var lastSendRequest: MessageRequest?

    // MARK: - Convenience factories

    static func makeCannedMessage(text: String = "Hello from mock") -> Message {
        Message(
            id: "msg_test",
            type: "message",
            role: .assistant,
            content: [ContentBlock(type: "text", text: text)],
            model: "claude-test",
            stopReason: "end_turn",
            stopSequence: nil,
            usage: Usage(inputTokens: 5, outputTokens: 10)
        )
    }

    static func makeStreamEvents(texts: [String] = ["Hello", " world"]) -> [StreamEvent] {
        var events: [StreamEvent] = [
            .messageStart(messageId: "stream_test"),
            .contentBlockStart(index: 0, type: "text")
        ]
        for (i, text) in texts.enumerated() {
            events.append(.contentBlockDelta(index: 0, textDelta: text))
            _ = i  // suppress unused warning
        }
        events.append(.contentBlockStop(index: 0))
        events.append(.messageDelta(stopReason: "end_turn", outputTokens: 5))
        events.append(.messageStop)
        return events
    }

    // MARK: - Init

    init(
        sendResult: MockSendResult = .success(MockLLMService.makeCannedMessage()),
        streamResult: MockStreamResult = .events(MockLLMService.makeStreamEvents())
    ) {
        self.sendResult = sendResult
        self.streamResult = streamResult
    }

    // MARK: - LLMService

    func send(_ request: MessageRequest) async throws -> Message {
        lastSendRequest = request
        switch sendResult {
        case .success(let msg): return msg
        case .failure(let err): throw err
        }
    }

    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        switch streamResult {
        case .events(let events):
            return AsyncThrowingStream { continuation in
                for event in events {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        case .failure(let err):
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: err)
            }
        }
    }
}
