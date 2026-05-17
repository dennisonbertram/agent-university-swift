// ChatViewModel.swift — STUB for RED phase
// NO import SwiftUI — view model stays UI-framework-free for cross-platform portability

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

    // MARK: - Public API (STUB — returns wrong values, tests will fail behaviorally)

    public func send(userText: String) async {
        // STUB: appends user message but sets a wrong error and does not stream
        // Tests will fail because: no assistant message, errorMessage is wrong, isStreaming stays false
        let userMsg = ChatMessage(role: .user, text: userText)
        messages.append(userMsg)
        // STUB: does not call service, does not produce assistant message
        // BT-001 fails: messages.count == 1 not 2
        // BT-003 fails: errorMessage is nil not set for 401 case
    }

    public func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    public func clear() {
        messages.removeAll()
        errorMessage = nil
    }
}
