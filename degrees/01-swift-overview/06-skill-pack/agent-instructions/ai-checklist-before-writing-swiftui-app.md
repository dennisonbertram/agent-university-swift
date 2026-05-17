# Pre-flight Checklist — Before Writing a SwiftUI App

[Back to index](../index.md) | Related: [ai-system-prompt-swift.md](ai-system-prompt-swift.md), [lesson-08](../lessons/lesson-08-swiftui-macos-app.md), [lesson-09](../lessons/lesson-09-multiplatform-swift-packages.md)

Run through this list before writing any SwiftUI view or view model code.

---

## Observable pattern (use the new API)

- [ ] View models use `@Observable` macro — NOT `class MyVM: ObservableObject`
- [ ] View model stored properties are plain `var` — NOT `@Published var`
- [ ] Views hold owned view models with `@State private var vm = MyVM()` — NOT `@StateObject`
- [ ] Child views that need two-way binding use `@Bindable var vm: MyVM` — NOT `@ObservedObject`
- [ ] View models are `final class` annotated `@MainActor @Observable`

## View model isolation

- [ ] View model file imports only `Foundation` and `Observation` — NOT `import SwiftUI`
- [ ] The `@Observable` macro comes from `Observation` framework (implicitly via `Foundation` on Apple platforms)
- [ ] Business logic (LLM calls, state management) lives in the view model — not in view `body`

## Async task management

- [ ] Long-running work is started in `.task { }` view modifier — NOT in `onAppear`
- [ ] The `.task { }` modifier automatically cancels the task when the view disappears
- [ ] If starting tasks manually (`Task { }`), store the task in the view model and cancel it in a cleanup path
- [ ] `await MainActor.run { ... }` wraps any state mutations called from background tasks

## Platform targeting

- [ ] `Package.swift` `platforms:` includes both targets for multiplatform: `[.macOS(.v14), .iOS(.v17)]`
- [ ] The shared library target does NOT contain `@main` — the `@main` struct is in a platform-specific app shell
- [ ] macOS app shell uses `WindowGroup` in a `Scene`
- [ ] iOS app shell wraps content in `NavigationStack`

## Cross-platform modifiers

- [ ] Used only cross-platform modifiers in shared views (no guard needed):
  - `.navigationTitle`, `.padding`, `.frame`, `.background`, `.font`
  - `.task`, `.onChange`, `.disabled`, `.opacity`, `.cornerRadius`, `.overlay`
  - `NavigationStack`, `ScrollView`, `VStack`, `HStack`, `ZStack`
  - `TextField("placeholder", text: $binding, axis: .vertical)`
  - `Button("label") { action }`

- [ ] iOS-only modifiers are wrapped with `#if os(iOS)`:
  - `.navigationBarTitleDisplayMode(.inline)`
  - `.submitLabel(.send)`
  - `.keyboardType(.default)`
  - `.autocorrectionDisabled()`

- [ ] macOS-only modifiers are wrapped with `#if os(macOS)`:
  - `.windowResizability(.contentSize)`
  - `Settings { }`, `MenuBarExtra`

## Platform guard granularity

- [ ] `#if os()` guards are placed at the modifier level — NOT around entire view bodies
- [ ] Whole-body platform splits (`#if os(iOS) public var body ... #else ...`) are avoided — they cause code duplication

## Forbidden imports in shared library

- [ ] Shared library targets do NOT import `AppKit` (macOS-only framework)
- [ ] Shared library targets do NOT import `UIKit` (iOS-only framework)
- [ ] `swift build` compiling only macOS won't catch iOS-only API — verify multiplatform builds in Xcode

## UUID-keyed assistant message tracking

- [ ] When streaming assistant output, each assistant turn is identified by a `UUID` set at stream start
- [ ] Append text by looking up the message by UUID: `messages[id]?.text += chunk`
- [ ] Do NOT use array indices to track the in-progress assistant message (indices shift)

## Error rollback

- [ ] A boolean flag (`assistantStarted`) tracks whether any delta has been received
- [ ] On error: if `assistantStarted`, mark the message as failed; if not, remove the placeholder
- [ ] On cancellation: same three-branch pattern (cancel / pre-delta / post-delta)

## Testing SwiftUI view models

- [ ] `@Suite` for a `@MainActor` view model is itself annotated `@MainActor`
- [ ] Tests inject `MockLLMService` — do not test against the live API
- [ ] `MockLLMService` is `@unchecked Sendable` with documented isolation

## Before shipping to macOS

- [ ] The macOS window actually opens (not hidden — check `WindowGroup` is not wrapped in `#if os(iOS)`)
- [ ] `onSubmit { }` works on macOS with Return key — test it
- [ ] Window title is set via `.navigationTitle` on the inner view (macOS renders it in the title bar)

---

See also: [recipe-swiftui-streaming-text](../recipes/recipe-swiftui-streaming-text.md), [ref-swiftui-cross-platform-modifiers](../reference/ref-swiftui-cross-platform-modifiers.md), [example-l5-chatviewmodel](../examples/example-l5-chatviewmodel.md)

Evidence: `05-distillation/patterns/mainactor-observable-viewmodel.md`, `05-distillation/patterns/cross-platform-swiftui-guards.md`, `05-distillation/gotchas/`.
