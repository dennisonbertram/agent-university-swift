# Example — L5: `ChatViewModel` — `@MainActor @Observable`

[Back to index](../index.md) | POC: `degrees/01-swift-overview/03-pocs/L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift`

## What this example demonstrates

- `@MainActor @Observable` view model structure.
- UUID-keyed assistant message tracking for rollback.
- Mutation from a background stream task via `await MainActor.run`.
- `cancel()` and `clear()` operations.

## Class declaration

```swift
// ChatViewModel.swift ~line 7
import AnthropicClient
import Foundation
import Observation          // NOT SwiftUI — cross-platform compatible

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
```

Source: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:7-32`. Key: `import Observation` not `import SwiftUI`.

## `send(userText:)` — UUID-keyed approach

```swift
// ChatViewModel.swift ~line 42
public func send(userText: String) async {
    // Append user message
    messages.append(ChatMessage(role: .user, text: userText))
    errorMessage = nil

    // Build snapshot for the outgoing request
    let snapshot = messages.map { InputMessage(role: $0.role, content: .text($0.text)) }
    let request = MessageRequest(model: model, maxTokens: maxTokens,
                                 messages: snapshot, system: system,
                                 temperature: nil, stream: true)

    // Append placeholder for the assistant message — gives it a stable UUID
    let assistantId = UUID()
    messages.append(ChatMessage(id: assistantId, role: .assistant, text: "", isStreaming: true))
    isStreaming = true

    let serviceLocal = service   // capture before the Task closure
    streamTask = Task { [weak self] in
        guard let self else { return }
        do {
            for try await event in serviceLocal.stream(request) {
                try Task.checkCancellation()
                switch event {
                case .contentBlockDelta(_, let chunk):
                    // Back on main actor for mutation
                    await MainActor.run { self.appendDelta(toId: assistantId, chunk: chunk) }
                case .messageStop:
                    await MainActor.run { self.finishStreaming(id: assistantId) }
                    return
                default: break
                }
            }
            await MainActor.run { self.finishStreaming(id: assistantId) }
        } catch is CancellationError {
            await MainActor.run { self.finishStreaming(id: assistantId) }
        } catch {
            await MainActor.run { self.rollbackAssistant(id: assistantId, error: error) }
        }
    }
    await streamTask?.value
}
```

Source: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:42-119`.

## Helper methods

```swift
private func appendDelta(toId id: UUID, chunk: String) {
    guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[idx].text += chunk
}

private func finishStreaming(id: UUID) {
    if let idx = messages.firstIndex(where: { $0.id == id }) {
        messages[idx].isStreaming = false
    }
    isStreaming = false
}

private func rollbackAssistant(id: UUID, error: Error) {
    messages.removeAll { $0.id == id }   // remove placeholder
    isStreaming = false
    errorMessage = humanReadable(error)
}

public func cancel() { streamTask?.cancel(); streamTask = nil; isStreaming = false }
public func clear() { messages.removeAll(); errorMessage = nil }
```

## What to notice

1. The `assistantId` UUID is minted BEFORE the stream starts. Rollback uses `.firstIndex(where: { $0.id == id })` — even after deltas have been appended, the correct message is found.

2. `await MainActor.run { self.appendDelta(...) }` — the stream loop runs in a detached `Task` (not necessarily on the main actor), so mutations go through `MainActor.run`.

3. `let serviceLocal = service` — captures the service as a `let` before the `Task` closure. The `[weak self]` capture prevents a retain cycle; the `let serviceLocal` avoids a mutable capture error.

4. `await streamTask?.value` at the end of `send` — waits for the stream task to complete before returning. This makes `send` usable with `Task { await vm.send(userText: text) }` from a button action.
