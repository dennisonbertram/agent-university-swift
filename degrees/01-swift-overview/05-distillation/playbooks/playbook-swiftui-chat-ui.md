# Playbook: SwiftUI chat UI with `@Observable` view model + streaming updates

**Goal**: A SwiftUI macOS app that consumes L2's `AnthropicClient` and renders streamed responses into a chat list, with cancellation support.

## Prerequisites
- macOS 14+ deployment target (required by `@Observable`).
- L2 `AnthropicClient` available via SwiftPM.
- Command Line Tools is sufficient for `swift build` — Xcode is NOT required for build verification (see gotcha `gotchas/swiftui-builds-with-clt-but-cannot-launch.md` for the runtime caveat).

## Steps

1. `Package.swift`:
   ```swift
   // swift-tools-version: 6.1
   import PackageDescription

   let package = Package(
       name: "L5-swiftui-macos-app",
       platforms: [.macOS(.v14)],
       products: [
           .executable(name: "ChatMacApp", targets: ["ChatMacApp"]),
           .library(name: "ChatAppCore", targets: ["ChatAppCore"])
       ],
       dependencies: [.package(path: "../L2-anthropic-client")],
       targets: [
           .target(name: "ChatAppCore",
                   dependencies: [.product(name: "AnthropicClient", package: "L2-anthropic-client")]),
           .executableTarget(name: "ChatMacApp", dependencies: ["ChatAppCore"]),
           .testTarget(name: "ChatAppCoreTests", dependencies: ["ChatAppCore"])
       ]
   )
   ```

2. Write the view model in the **library target** with NO `import SwiftUI` (cross-platform pin — see anti-pattern `anti-patterns/import-swiftui-in-viewmodel.md`):

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

       public init(service: any LLMService, model: String = "claude-sonnet-4-5-20250929",
                   maxTokens: Int = 1024, system: String? = nil) { /* ... */ }

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
       // appendDelta, finishStreaming, rollbackAssistant, humanReadable helpers
   }
   ```

3. Write the views in the **executable target** with `@Bindable` on child views:
   ```swift
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

   struct ContentView: View {
       @Bindable var vm: ChatViewModel
       var body: some View {
           VStack(spacing: 0) {
               // header with Clear button
               // ScrollView of MessageRows with ScrollViewReader auto-scroll
               // optional errorMessage banner
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

4. Test the view model with a `MockLLMService` (use `@MainActor @Suite`):
   ```swift
   @MainActor
   @Suite("ChatViewModel")
   struct ChatViewModelTests {
       @Test func deltasAccumulateIntoFinalAssistantMessage() async {
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

5. Build and run:
   ```bash
   swift build       # exit 0 on CLT alone
   swift test        # view-model tests pass
   ANTHROPIC_API_KEY=... swift run ChatMacApp
   ```

## You'll know it worked when…
- `swift test` passes 6+ ChatViewModel behavioural tests with no Anthropic call.
- The macOS app shows tokens streaming in live (one chunk at a time, not all at once).
- Pressing Stop mid-stream halts text growth and re-enables the Send button.
- `humanReadable(error)` surfaces a user-readable message for 401 / 429 / etc.

## Evidence
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:1-135` — full view model.
- POC: `L5-swiftui-macos-app/Sources/ChatMacApp/ChatMacApp.swift:1-23`, `ContentView.swift:1-55`, `Components/InputBar.swift:1-30`, `Components/MessageRow.swift` — views.
- POC: `L5-swiftui-macos-app/Tests/ChatAppCoreTests/ChatViewModelTests.swift:1-184` — 6 BT tests + 2 regression pins.
- Research: `01-research/05-swiftui-multiplatform.md` §3-§4 — `@Observable`, `@Bindable`, `.task`, streaming patterns.
- See also: pattern `patterns/mainactor-observable-viewmodel.md`, pattern `patterns/error-rollback-state-machine.md`, before-you-build `before-you-build/swiftui-multiplatform.md`.
