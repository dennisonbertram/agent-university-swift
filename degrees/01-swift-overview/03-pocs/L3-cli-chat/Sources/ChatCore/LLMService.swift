// LLMService.swift — protocol seam that tests inject into
import AnthropicClient

public protocol LLMService: Sendable {
    /// Streams response events. Implementation may call Anthropic, mock, or local.
    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error>
}

extension AnthropicClient: LLMService {
    // AnthropicClient already has `stream(_:)`, so this is a no-op conformance.
}
