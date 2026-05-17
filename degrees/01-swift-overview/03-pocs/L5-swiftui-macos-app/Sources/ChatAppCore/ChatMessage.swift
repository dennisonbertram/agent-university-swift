// ChatMessage.swift — value type for a single turn in the conversation

import Foundation
import AnthropicClient

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let role: Role
    public var text: String
    public var isStreaming: Bool

    public init(id: UUID = UUID(), role: Role, text: String, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
    }
}
