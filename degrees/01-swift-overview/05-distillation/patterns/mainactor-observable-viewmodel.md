# Pattern: `@MainActor @Observable` view model owns mutation, view binds with `@Bindable`

**Category**: pattern

## What
The SwiftUI view model is a `final class` annotated with `@MainActor` (so all of its state mutates on the main thread) and `@Observable` (so SwiftUI tracks reads automatically — no `@Published`, no `ObservableObject`). The owning view declares `@State private var vm = ChatViewModel(...)`. Child views that need to mutate via two-way bindings declare `@Bindable var vm: ChatViewModel` and use `$vm.draft` for `TextField` bindings.

## When to apply
- Every SwiftUI view model in this corpus.
- Any reference-type owner of mutable UI state on macOS 14+ / iOS 17+ (the minimum for `@Observable`).

## Canonical code

The view model — note it does NOT `import SwiftUI`:

```swift
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

    public init(service: any LLMService,
                model: String = "claude-sonnet-4-5-20250929",
                maxTokens: Int = 1024,
                system: String? = nil) {
        self.service = service
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
    }

    public func send(userText: String) async { /* ... */ }
    public func cancel() { streamTask?.cancel(); streamTask = nil; isStreaming = false }
    public func clear() { messages.removeAll(); errorMessage = nil }
}
```

The owning app holds the view model with `@State`:

```swift
import SwiftUI
import ChatCore

@main
struct ChatMacApp: App {
    @State private var vm: ChatViewModel = {
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        return ChatViewModel(service: AnthropicClient(apiKey: key))
    }()

    var body: some Scene {
        WindowGroup("Claude Chat") {
            RootView(vm: vm).frame(minWidth: 500, minHeight: 600)
        }
    }
}
```

A child view that mutates two-way bindings:

```swift
struct ChatScreen: View {
    @Bindable public var vm: ChatViewModel

    var body: some View {
        InputBar(draft: $vm.draft, isStreaming: vm.isStreaming) {
            let text = vm.draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            vm.draft = ""
            Task { await vm.send(userText: text) }
        } onCancel: { vm.cancel() }
    }
}
```

## Variants and trade-offs
- `@MainActor` is on the **class**, not on individual methods. All stored property reads/writes are MainActor-isolated.
- When you must mutate from a non-MainActor context (e.g. inside an `AsyncThrowingStream` stream task), wrap mutations in `await MainActor.run { self.appendDelta(...) }`.
- `@State private var vm = ChatViewModel(...)` — the `@State` storage is owned by the view; SwiftUI keeps it alive across re-renders.
- Children take the view model as a non-`@State` `@Bindable` parameter (or just plain `var`). They do not own it.
- Tests run on `@MainActor` themselves: `@MainActor @Suite struct ChatViewModelTests`.

## Evidence
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:7-32` — class-level `@MainActor @Observable`.
- POC: `L5-swiftui-macos-app/Sources/ChatMacApp/ChatMacApp.swift:9-23` — `@State private var viewModel: ChatViewModel = { ... }()`.
- POC: `L5-swiftui-macos-app/Sources/ChatMacApp/ContentView.swift:6-7` — `@Bindable var vm: ChatViewModel`; `InputBar(draft: $vm.draft, ...)`.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/ChatViewModel.swift:8-33` — same shape, cross-platform.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/Views/ChatScreen.swift:7-9` — `public struct ChatScreen: View { @Bindable public var vm: ChatViewModel }`.
- Research: `01-research/05-swiftui-multiplatform.md` §3 lines 92-138 — `@Observable` + `@Bindable` reference.
- Research: `01-research/06-expectation-gaps.md` EG-04 lines 80-98 — `ObservableObject` → `@Observable` migration table.
- See also: ADR `decision-records/adr-005-no-import-swiftui-in-viewmodel.md`, anti-pattern `anti-patterns/import-swiftui-in-viewmodel.md`.
