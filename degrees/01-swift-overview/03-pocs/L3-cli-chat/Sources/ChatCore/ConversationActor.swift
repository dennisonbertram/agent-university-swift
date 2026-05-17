// ConversationActor.swift — actor wrapping messages history (STUBBED for RED phase)
import AnthropicClient

public actor ConversationActor {
    public private(set) var messages: [InputMessage] = []
    public init() {}

    public func append(role: Role, text: String) {
        // STUB: intentionally does nothing — tests will fail
    }

    public func appendOrExtend(role: Role, deltaText: String) {
        // STUB: intentionally does nothing — tests will fail
    }

    public func snapshot() -> [InputMessage] {
        // STUB: returns empty — tests expecting messages will fail
        return []
    }

    public func removeLast() {
        // STUB: does nothing
    }

    public func count() -> Int {
        // STUB: always returns 0 — tests expecting > 0 will fail
        return 0
    }
}
