// ChatSession.swift — send(userText:) → AsyncThrowingStream<String, Error>
import AnthropicClient

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
    /// On error before any assistant output, the user message is rolled back.
    /// On cancellation, partial response is retained — user turn stays in history.
    public func send(userText: String) -> AsyncThrowingStream<String, Error> {
        let service = self.service
        let model = self.model
        let maxTokens = self.maxTokens
        let system = self.system
        let history = self.history

        return AsyncThrowingStream { continuation in
            let task = Task {
                await history.append(role: .user, text: userText)
                let snapshot = await history.snapshot()
                let req = MessageRequest(
                    model: model,
                    maxTokens: maxTokens,
                    messages: snapshot,
                    system: system,
                    temperature: nil,
                    stream: true
                )

                var assistantStarted = false
                do {
                    for try await event in service.stream(req) {
                        try Task.checkCancellation()
                        switch event {
                        case .contentBlockDelta(_, let text):
                            if !assistantStarted {
                                await history.append(role: .assistant, text: "")
                                assistantStarted = true
                            }
                            await history.appendOrExtend(role: .assistant, deltaText: text)
                            continuation.yield(text)
                        case .messageStop:
                            continuation.finish()
                            return
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    // Partial response is retained — user turn stays in history
                    continuation.finish()
                } catch {
                    // On hard error, roll back only if assistant never started
                    if !assistantStarted {
                        await history.removeLast()
                    }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
