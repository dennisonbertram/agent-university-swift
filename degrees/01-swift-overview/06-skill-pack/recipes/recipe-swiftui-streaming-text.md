# Recipe — SwiftUI Streaming Text with `@Observable` View Model

[Back to index](../index.md) | See also: [lesson-08-swiftui-macos-app.md](../lessons/lesson-08-swiftui-macos-app.md) | Pattern: `patterns/mainactor-observable-viewmodel.md`

## Use this when

You need a SwiftUI view that renders LLM text deltas in real time as they stream from an `AsyncThrowingStream`.

## View model (library target, no `import SwiftUI`)

```swift
// Sources/ChatAppCore/ChatViewModel.swift
import AnthropicClient
import Foundation
import Observation           // NOT SwiftUI

@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage] = []
    public private(set) var isStreaming: Bool = false
    public var errorMessage: String? = nil
    public var draft: String = ""

    private var streamTask: Task<Void, Never>? = nil

    public let service: any LLMService
    public let model: String
    public let maxTokens: Int

    public init(service: any LLMService,
                model: String = "claude-sonnet-4-5-20250929",
                maxTokens: Int = 1024) {
        self.service = service
        self.model = model
        self.maxTokens = maxTokens
    }

    public func send(userText: String) async {
        messages.append(ChatMessage(role: .user, text: userText))
        errorMessage = nil

        let snapshot = messages.map { InputMessage(role: $0.role, content: .text($0.text)) }
        let request = MessageRequest(model: model, maxTokens: maxTokens,
                                     messages: snapshot, stream: true)
        let assistantId = UUID()
        messages.append(ChatMessage(id: assistantId, role: .assistant,
                                    text: "", isStreaming: true))
        isStreaming = true

        let serviceLocal = service
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

    public func cancel() { streamTask?.cancel(); streamTask = nil; isStreaming = false }
    public func clear() { messages.removeAll(); errorMessage = nil }

    private func appendDelta(toId id: UUID, chunk: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text += chunk
    }

    private func finishStreaming(id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].isStreaming = false
        isStreaming = false
    }

    private func rollbackAssistant(id: UUID, error: Error) {
        messages.removeAll { $0.id == id }
        isStreaming = false
        errorMessage = error.localizedDescription
    }
}
```

## Root view (executable target)

```swift
import SwiftUI
import ChatAppCore

@main
struct ChatMacApp: App {
    @State private var vm: ChatViewModel = {
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        return ChatViewModel(service: AnthropicClient(apiKey: key))
    }()

    var body: some Scene {
        WindowGroup("Claude Chat") {
            ContentView(vm: vm).frame(minWidth: 500, minHeight: 600)
        }
    }
}

struct ContentView: View {
    @Bindable var vm: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.messages) { msg in
                            MessageRow(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) { _ , _ in
                    if let last = vm.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).padding(.horizontal)
            }
            InputBar(draft: $vm.draft, isStreaming: vm.isStreaming) {
                let text = vm.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                vm.draft = ""
                Task { await vm.send(userText: text) }
            } onCancel: { vm.cancel() }
        }
    }
}
```

Evidence: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift`; `L5-swiftui-macos-app/Sources/ChatMacApp/`.
