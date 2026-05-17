# Pattern: `#if os(iOS)` guards around the small set of navigation/keyboard modifiers that diverge

**Category**: pattern

## What
Most SwiftUI views compile unchanged on both macOS and iOS — `VStack`, `Text`, `Button`, `TextField`, `ScrollView`, `NavigationStack`, the `.task` modifier, etc. The handful of modifiers that are iOS-only (`.navigationBarTitleDisplayMode(.inline)`, `.submitLabel(.send)`) or macOS-only (`.windowResizability`, `Settings` scene, `MenuBarExtra`) get tightly-scoped `#if os(iOS)` / `#if os(macOS)` guards on the exact modifier or scene, not on whole files. The view model contains no guards at all.

## When to apply
- Every cross-platform SwiftUI view in this corpus (L6 and capstone).
- Whenever a SwiftUI API is platform-specific *but* its absence on the other platform would not change behaviour meaningfully.

## Canonical code

```swift
import SwiftUI
import AnthropicClient

public struct ChatScreen: View {
    @Bindable public var vm: ChatViewModel
    public init(vm: ChatViewModel) { self.vm = vm }

    public var body: some View {
        VStack(spacing: 0) {
            messagesScroll
            if let err = vm.errorMessage {
                Text(err).foregroundColor(.red).padding(.horizontal).padding(.bottom, 4)
            }
            InputBar(draft: $vm.draft, isStreaming: vm.isStreaming, onSend: { /* ... */ }, onCancel: { vm.cancel() })
        }
        .navigationTitle("Claude")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

public struct InputBar: View {
    @Binding public var draft: String
    public let isStreaming: Bool
    public let onSend: () -> Void
    public let onCancel: () -> Void

    public var body: some View {
        HStack(spacing: 8) {
            TextField("Type a message…", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit(onSend)
                .disabled(isStreaming)
                #if os(iOS)
                .submitLabel(.send)
                #endif
            // ...
        }
    }
}
```

For app shells, guards land in the `App.body`:

```swift
@main
struct ChatMacApp: App {
    var body: some Scene {
        WindowGroup("Claude Chat") { RootView(vm: vm) }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
```

## Variants and trade-offs
- Keep guards as fine-grained as possible: a single chained modifier, not an entire `body`. This keeps platform-specific behaviour visible inline and avoids divergent two-platform branches.
- If a view needs structurally different layouts per platform, factor a small platform-specific subview rather than splitting the parent — but most of the time, identical bodies with two `#if`-guarded modifiers is enough.
- **Never** put `#if` guards inside the view model. If you find yourself wanting to, the abstraction is wrong — push the divergence up to the view shell. The L6/capstone REGRESSION-002 test pins this (see anti-pattern `anti-patterns/import-swiftui-in-viewmodel.md`).

## Evidence
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/Views/ChatScreen.swift:27-29` — `#if os(iOS) .navigationBarTitleDisplayMode(.inline) #endif`.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/Views/InputBar.swift:30-32` — `#if os(iOS) .submitLabel(.send) #endif`.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/Views/ChatScreen.swift:27-29` — same.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/Views/InputBar.swift:30-32` — same.
- Research: `01-research/05-swiftui-multiplatform.md` §5 lines 263-300 — list of cross-platform vs platform-specific APIs.
- Planning: `02-planning/01-shared-package-strategy.md` §6 lines 219-233 — table of expected guards.
- See also: pattern `patterns/multiplatform-spm-package.md`.
