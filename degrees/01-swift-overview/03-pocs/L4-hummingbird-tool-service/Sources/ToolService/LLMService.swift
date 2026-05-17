// LLMService.swift — Local protocol seam for the LLM backend.
//
// This protocol is defined here in L4 rather than depending on L3's ChatCore.
// That keeps L4 self-contained: the only cross-package dependency is L2 (AnthropicClient)
// for the concrete model types (MessageRequest, Message, StreamEvent, AnthropicError).
//
// AnthropicClient already satisfies this protocol structurally — the conformance
// declaration in this file makes it official.

import AnthropicClient

public protocol LLMService: Sendable {
    func send(_ request: MessageRequest) async throws -> Message
    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error>
}

extension AnthropicClient: LLMService {}
