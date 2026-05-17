// ConversationActor.swift — actor wrapping messages history
import AnthropicClient

public actor ConversationActor {
    public private(set) var messages: [InputMessage] = []
    public init() {}

    public func append(role: Role, text: String) {
        messages.append(InputMessage(role: role, content: .text(text)))
    }

    public func appendOrExtend(role: Role, deltaText: String) {
        // If last message is same role with .text content, coalesce; else add new.
        if let last = messages.last,
           last.role == role,
           case .text(let existing) = last.content {
            messages[messages.count - 1] = InputMessage(role: role, content: .text(existing + deltaText))
        } else {
            messages.append(InputMessage(role: role, content: .text(deltaText)))
        }
    }

    public func snapshot() -> [InputMessage] { messages }

    public func removeLast() {
        if !messages.isEmpty { messages.removeLast() }
    }

    public func count() -> Int { messages.count }
}
