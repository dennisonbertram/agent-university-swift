// LLMService.swift — protocol seam; thin wrapper over AnthropicClient

import AnthropicClient

public protocol LLMService: Sendable {
    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error>
}

extension AnthropicClient: LLMService {}
