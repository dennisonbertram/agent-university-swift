// ChatSession.swift — send(userText:) → AsyncThrowingStream<String, Error> (STUBBED for RED phase)
import AnthropicClient
import Foundation

public struct ChatSession: Sendable {
    public let service: any LLMService
    public let model: String
    public let maxTokens: Int
    public let system: String?
    public let history: ConversationActor

    public init(service: any LLMService,
                model: String,
                maxTokens: Int = 1024,
                system: String? = nil,
                history: ConversationActor = ConversationActor()) {
        self.service = service
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.history = history
    }

    /// Sends a user turn. Returns an AsyncThrowingStream that yields text chunks
    /// as they arrive. On completion the assistant message is committed to history.
    /// On error or cancellation, the user message is rolled back so retry is clean.
    public func send(userText: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: NSError(domain: "unimplemented", code: 0))
        }
    }
}
