// MockLLMService.swift — test-only mock for LLMService

import AnthropicClient
@testable import ChatAppCore

final class MockLLMService: LLMService, @unchecked Sendable {
    var events: [StreamEvent] = []
    var error: Error?
    private(set) var capturedRequests: [MessageRequest] = []

    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        capturedRequests.append(request)
        let events = self.events
        let error = self.error
        return AsyncThrowingStream { continuation in
            Task {
                for ev in events {
                    continuation.yield(ev)
                    await Task.yield()
                }
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
        }
    }
}

/// GatedMockLLMService yields a small delay mid-stream so tests can observe isStreaming == true.
final class GatedMockLLMService: LLMService, @unchecked Sendable {
    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.messageStart(messageId: "m1"))
                continuation.yield(.contentBlockDelta(index: 0, textDelta: "Hel"))
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms pause
                continuation.yield(.contentBlockDelta(index: 0, textDelta: "lo!"))
                continuation.yield(.messageStop)
                continuation.finish()
            }
        }
    }
}
