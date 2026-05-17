// MockLLMService.swift — test-only mock for LLMService
import AnthropicClient
@testable import ChatCore

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
                    // Slight async pause to let consumers cancel between events
                    await Task.yield()
                }
                if let error { continuation.finish(throwing: error) } else { continuation.finish() }
            }
        }
    }
}
