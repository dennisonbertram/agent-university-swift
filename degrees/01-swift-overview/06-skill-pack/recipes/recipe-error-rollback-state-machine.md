# Recipe — Error Rollback State Machine

[Back to index](../index.md) | See also: [lesson-06-cli-tools-with-argument-parser.md](../lessons/lesson-06-cli-tools-with-argument-parser.md) | Pattern: `patterns/error-rollback-state-machine.md`

## Use this when

A streaming LLM turn can fail at different points, and you need different rollback behaviours depending on whether output was already delivered.

## The three branches

| Condition | Action |
|-----------|--------|
| `CancellationError` (user said stop) | Keep partial state; do not throw |
| Hard error, assistant never started | Roll back user message |
| Hard error, after first assistant delta | Keep partial; surface error |

## In a CLI `ChatSession`

```swift
public func send(userText: String) -> AsyncThrowingStream<String, Error> {
    let history = self.history
    let service = self.service
    let model = self.model
    let maxTokens = self.maxTokens
    let system = self.system

    return AsyncThrowingStream { continuation in
        let task = Task {
            await history.append(role: .user, text: userText)
            let snapshot = await history.snapshot()
            let req = MessageRequest(model: model, maxTokens: maxTokens,
                                     messages: snapshot, system: system,
                                     temperature: nil, stream: true)
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
                        continuation.finish(); return
                    default: break
                    }
                }
                continuation.finish()
            } catch is CancellationError {
                // User cancelled — keep whatever was accumulated
                continuation.finish()
            } catch {
                // Hard error: only roll back user message if assistant never started
                if !assistantStarted { await history.removeLast() }
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

Evidence: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:34-80`.

## In a `@MainActor` view model

```swift
private func rollbackAssistant(id: UUID, error: Error) {
    messages.removeAll { $0.id == id }    // remove the placeholder message
    isStreaming = false
    errorMessage = humanReadable(error)
}

private func finishStreaming(id: UUID) {
    if let idx = messages.firstIndex(where: { $0.id == id }) {
        messages[idx].isStreaming = false
    }
    isStreaming = false
}
```

The `assistantId` UUID is minted before the stream starts. On error before any delta: `rollbackAssistant(id:error:)`. On error after at least one delta: `finishStreaming(id:)` + set `errorMessage`.

Evidence: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:61-119`.

## Tests that pin this behaviour

```swift
@Test("BT-004: error before delta rolls back user message")
func errorBeforeDeltaRollsBackUser() async throws {
    let mock = MockLLMService()
    mock.error = AnthropicError.unauthorized(body: "bad key")
    let session = ChatSession(service: mock, model: "m", maxTokens: 100)
    do {
        for try await _ in session.send(userText: "hi") {}
    } catch {}
    let count = await session.history.count()
    #expect(count == 0, "User message should be rolled back on error before any delta")
}

@Test("BT-005: error after one delta keeps partial")
func errorAfterOneDeltaKeepsPartial() async throws {
    let mock = MockLLMService()
    mock.events = [.contentBlockDelta(index: 0, textDelta: "Partial")]
    mock.error = AnthropicError.serverError(status: 500, body: "oops")
    // ...
    // After: history has 2 messages (user + partial assistant)
}
```

Evidence: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:38-96`.
