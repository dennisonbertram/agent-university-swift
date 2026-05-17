// MockUpstreamLLMService.swift — upstream mock used by the backend in tests
// Captures requests, yields canned StreamEvents, never calls Anthropic.

import Foundation
import AnthropicClient
import ChatCore

/// Thread-safe mock LLMService for backend injection in tests.
final class MockUpstreamLLMService: LLMService, @unchecked Sendable {

    // MARK: - State (protected by NSLock for thread safety across service isolation)

    private let lock = NSLock()
    private var _capturedRequests: [MessageRequest] = []
    private var _events: [StreamEvent] = [
        .messageStart(messageId: "mock-1"),
        .contentBlockDelta(index: 0, textDelta: "Hello"),
        .contentBlockDelta(index: 0, textDelta: " world"),
        .messageStop
    ]
    private var _throwError: Error? = nil

    var events: [StreamEvent] {
        get { lock.withLock { _events } }
        set { lock.withLock { _events = newValue } }
    }

    var throwError: Error? {
        get { lock.withLock { _throwError } }
        set { lock.withLock { _throwError = newValue } }
    }

    var capturedRequests: [MessageRequest] {
        lock.withLock { _capturedRequests }
    }

    // MARK: - LLMService

    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        lock.withLock { _capturedRequests.append(request) }
        let currentEvents = events
        let currentError = throwError

        return AsyncThrowingStream { continuation in
            if let error = currentError {
                continuation.finish(throwing: error)
                return
            }
            for event in currentEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}
