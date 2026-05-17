// BackendLLMService.swift — STUB for RED phase
// Client-side LLMService that talks to /chat/stream on the chat-backend

import AnthropicClient
import Foundation

public struct BackendLLMService: LLMService {
    public let baseURL: URL
    public let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        // STUB: immediately throws to fail tests
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: ClientError.badResponse)
        }
    }
}
