# Lesson 8 — SwiftUI macOS App

[Back to index](../index.md) | Prev: [Lesson 7](lesson-07-hummingbird-http-services.md) | Next: [Lesson 9](lesson-09-multiplatform-swift-packages.md)

## Goal

After this lesson you can build a SwiftUI macOS chat app with `@Observable` view model, `@Bindable` views, streaming response display, and cancellation support.

## Prerequisites

[Lesson 2](lesson-02-swift6-concurrency.md) — `@MainActor`, tasks.
[Lesson 5](lesson-05-anthropic-messages-api-streaming.md) — streaming LLM client.

## Concepts

### 8.1 `@Observable` vs `ObservableObject`

Swift 5.9+ introduces `@Observable` from the `Observation` framework. Use it instead of `ObservableObject` + `@Published` + `@StateObject`:

| Old (don't use) | New (use this) |
|-----------------|----------------|
| `class Foo: ObservableObject` | `@Observable final class Foo` |
| `@Published var x: Int` | `var x: Int` (no annotation) |
| `@StateObject var vm = Foo()` | `@State private var vm = Foo()` |
| `@ObservedObject var vm: Foo` | plain `var vm: Foo` (if read-only) |
| n/a | `@Bindable var vm: Foo` (for two-way bindings) |

Requires macOS 14+ / iOS 17+.

Evidence: `01-research/05-swiftui-multiplatform.md §3`; `01-research/06-expectation-gaps.md EG-04`.

### 8.2 View model layout

The view model lives in the **library target** (not the executable). It must NOT `import SwiftUI`:

```swift
// Sources/ChatAppCore/ChatViewModel.swift
import AnthropicClient
import Foundation
import Observation             // NOT SwiftUI

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
}
```

The `import Observation` (not `import SwiftUI`) keeps the view model cross-platform — it compiles on both macOS and iOS without framework-specific dependencies.

Evidence: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:7-32`; `anti-patterns/import-swiftui-in-viewmodel.md`.

### 8.3 `send(userText:)` with streaming

```swift
public func send(userText: String) async {
    let userMsg = ChatMessage(role: .user, text: userText)
    messages.append(userMsg)
    errorMessage = nil

    let snapshot = messages.map { InputMessage(role: $0.role, content: .text($0.text)) }
    let request = MessageRequest(model: model, maxTokens: maxTokens, messages: snapshot,
                                 system: system, temperature: nil, stream: true)
    let assistantId = UUID()
    messages.append(ChatMessage(id: assistantId, role: .assistant, text: "", isStreaming: true))
    isStreaming = true

    let serviceLocal = self.service   // capture for @Sendable closure
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
```

Evidence: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:42-119`.

### 8.4 Owning view with `@State`

```swift
// Sources/ChatMacApp/ChatMacApp.swift
import SwiftUI
import ChatAppCore

@main
struct ChatMacApp: App {
    @State private var viewModel: ChatViewModel = {
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        return ChatViewModel(service: AnthropicClient(apiKey: key))
    }()

    var body: some Scene {
        WindowGroup("Claude Chat") {
            ContentView(vm: viewModel).frame(minWidth: 500, minHeight: 600)
        }
        .windowResizability(.contentSize)
    }
}
```

`@State` owns the view model. `SwiftUI` keeps it alive across re-renders.

Evidence: `L5-swiftui-macos-app/Sources/ChatMacApp/ChatMacApp.swift:9-23`.

### 8.5 Child views with `@Bindable`

Child views that need two-way bindings use `@Bindable`:

```swift
struct ContentView: View {
    @Bindable var vm: ChatViewModel      // not @State — doesn't own it

    var body: some View {
        VStack(spacing: 0) {
            ScrollView { /* message list */ }
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

`$vm.draft` creates a `Binding<String>` from the `@Observable` property. This requires `@Bindable`.

Evidence: `L5-swiftui-macos-app/Sources/ChatMacApp/ContentView.swift:6-7`.

### 8.6 `swift build` works; `swift run` may not show a window

On macOS with Command Line Tools only (no Xcode.app), `swift build` succeeds. But `swift run ChatMacApp` may produce no visible window — the binary lacks the `.app` bundle wrapper, `Info.plist`, and LaunchServices registration that macOS needs to surface a GUI window.

Trust:
- `swift build` for compile-time verification
- `swift test` for view model unit tests (they run as test processes, not as GUI apps)
- Xcode for interactive macOS app runs

Evidence: `gotchas/swiftui-builds-with-clt-but-cannot-launch.md`.

### 8.7 Testing the view model

Tests are `@MainActor`-isolated because the view model is `@MainActor`:

```swift
import Testing
@testable import ChatAppCore

@MainActor
@Suite("ChatViewModel")
struct ChatViewModelTests {
    @Test("Deltas accumulate into assistant message")
    func deltasAccumulate() async {
        let mock = MockLLMService()
        mock.events = [
            .contentBlockDelta(index: 0, textDelta: "He"),
            .contentBlockDelta(index: 0, textDelta: "llo"),
            .contentBlockDelta(index: 0, textDelta: "!"),
            .messageStop
        ]
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "hi")
        #expect(vm.messages[1].text == "Hello!")
        #expect(vm.isStreaming == false)
    }
}
```

Evidence: `L5-swiftui-macos-app/Tests/ChatAppCoreTests/ChatViewModelTests.swift:1-184`.

## Pitfalls

- **`import SwiftUI` in the view model** → breaks cross-platform compilation. See [ts-multiplatform-package-fails-ios-only-api.md](../troubleshooting/ts-multiplatform-package-fails-ios-only-api.md).
- **Using `ObservableObject` + `@Published`** instead of `@Observable` → won't compile with macOS 14+ + Swift 6 patterns.
- **Not marking test suite `@MainActor`** when testing a `@MainActor` view model → async test methods may run off main actor.
- **`swift run` on macOS CLT** → binary exists but no window. Use Xcode for interactive runs.

## Exercise

Complete [lab-07-swiftui-counter.md](../labs/lab-07-swiftui-counter.md): a SwiftUI macOS app with an `@Observable` counter.

## Recap

- `@Observable` + `@Bindable` replaces `ObservableObject` + `@Published`.
- `@State` owns the view model in the root view; children use `@Bindable` for two-way bindings.
- View model lives in the library target. No `import SwiftUI` — use `import Observation`.
- `@MainActor` on the class binds all state mutations to the main thread.
- `swift build` works with CLT; `swift run` may not launch a window.
