// ChatViewModel.swift — full implementation: @Observable, MainActor-bound, streaming via LLMService

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

    // MARK: - Public API

    /// Send a user turn. Returns when the assistant message is fully committed or an error occurs.
    public func send(userText: String) async {
        let userMsg = ChatMessage(role: .user, text: userText)
        messages.append(userMsg)
        errorMessage = nil

        let snapshot = messages.map { msg in
            InputMessage(role: msg.role, content: .text(msg.text))
        }
        let request = MessageRequest(
            model: model,
            maxTokens: maxTokens,
            messages: snapshot,
            system: system,
            temperature: nil,
            stream: true
        )

        let assistantId = UUID()
        messages.append(ChatMessage(id: assistantId, role: .assistant, text: "", isStreaming: true))
        isStreaming = true

        let serviceLocal = self.service

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in serviceLocal.stream(request) {
                    try Task.checkCancellation()
                    switch event {
                    case .contentBlockDelta(_, let chunk):
                        await MainActor.run { self.appendDelta(toId: assistantId, chunk: chunk) }
                    case .messageStop:
                        await MainActor.run { self.finishStreaming(id: assistantId) }
                        return
                    default:
                        break
                    }
                }
                // Stream ended without messageStop — treat as complete
                await MainActor.run { self.finishStreaming(id: assistantId) }
            } catch is CancellationError {
                // Partial message stays; just mark streaming done
                await MainActor.run { self.finishStreaming(id: assistantId) }
            } catch {
                // Hard error: roll back in-progress assistant message, surface error
                await MainActor.run { self.rollbackAssistant(id: assistantId, error: error) }
            }
        }

        await streamTask?.value
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

    // MARK: - Private helpers

    private func appendDelta(toId id: UUID, chunk: String) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].text += chunk
        }
    }

    private func finishStreaming(id: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isStreaming = false
        }
        isStreaming = false
    }

    private func rollbackAssistant(id: UUID, error: Error) {
        messages.removeAll { $0.id == id }
        isStreaming = false
        errorMessage = humanReadable(error)
    }

    private func humanReadable(_ error: Error) -> String {
        if let e = error as? AnthropicError {
            switch e {
            case .unauthorized: return "Unauthorized — check ANTHROPIC_API_KEY."
            case .rateLimited(let retryAfter, _):
                return retryAfter.map { "Rate limited — retry after \($0)s." } ?? "Rate limited."
            case .badRequest(let body): return "Bad request: \(body)"
            case .serverError(let s, _): return "Server error \(s)."
            case .decodeFailure(let u): return "Decode error: \(u)"
            case .streamProtocol(let m): return "Stream error: \(m)"
            }
        }
        return "Unexpected error: \(error)"
    }
}
