// ChatViewModel.swift — STUB: empty implementation so red tests fail meaningfully

import AnthropicClient
import Foundation
import Observation

@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage] = []
    public private(set) var isStreaming: Bool = false
    public var errorMessage: String? = nil
    public var draft: String = ""

    public let service: any LLMService
    public let model: String
    public let maxTokens: Int
    public let system: String?

    private var streamTask: Task<Void, Never>? = nil

    public init(
        service: any LLMService,
        model: String = "claude-sonnet-4-5-20250929",
        maxTokens: Int = 1024,
        system: String? = nil
    ) {
        self.service = service
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
    }

    /// STUB: does nothing — tests will fail because messages stays empty
    public func send(userText: String) async {
        // intentionally empty stub
    }

    public func cancel() {
        // intentionally empty stub
    }

    public func clear() {
        // intentionally empty stub
    }
}
