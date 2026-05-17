# SwiftUI for macOS and iOS — Multiplatform

> Key finding: SwiftUI compiles with CLT-only toolchain on macOS 15. `import SwiftUI` and `@main App` work.
> Verified: runtime probe `/tmp/swift-research-probe/swiftui-test/` — Build complete! (34.67s), exit 0.
> iOS targets require full Xcode with simulator runtimes.

---

## 1. App Lifecycle — @main App Protocol

```swift
import SwiftUI

@main
struct ChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Rules**:
- Exactly one `@main` per app (and per `swift build` target)
- `App.body` returns `some Scene`
- `WindowGroup` is the primary cross-platform scene type
- On macOS: enables File > New Window; multiple independent instances
- On iOS: single foreground scene

**Cannot coexist with `main.swift`**: if you use `@main`, the file cannot be named `main.swift`.

---

## 2. Platform-Specific Scenes

```swift
@main
struct ChatApp: App {
    var body: some Scene {
        // Cross-platform
        WindowGroup("Chat") {
            ContentView()
        }
        
        #if os(macOS)
        // macOS only: Preferences window (wired to ⌘,)
        Settings {
            SettingsView()
        }
        
        // macOS only: menu bar item
        MenuBarExtra("Chat", systemImage: "bubble.left") {
            MenuBarContent()
        }
        #endif
    }
}
```

### Scene types by platform

| Scene | macOS | iOS | Notes |
|-------|-------|-----|-------|
| `WindowGroup` | ✅ | ✅ | Primary scene |
| `Window` | ✅ | iPadOS 16+ | Single named window |
| `Settings` | ✅ | ❌ | Preferences window |
| `MenuBarExtra` | ✅ | ❌ | Menu bar status item |
| `DocumentGroup` | ✅ | ✅ | Document-based apps |
| `ImmersiveSpace` | ❌ | ❌ | visionOS only |

---

## 3. State Management

### @State — local view state

```swift
struct CounterView: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") { count += 1 }
        }
    }
}
```

### @Observable (Swift 5.9+ / Xcode 15+) — preferred for view models

```swift
import Observation

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isLoading = false
    var inputText = ""
    
    func sendMessage() async {
        isLoading = true
        defer { isLoading = false }
        // call API...
        messages.append(ChatMessage(role: .assistant, text: "..."))
    }
}

// In the view — no @StateObject or @ObservedObject needed
struct ChatView: View {
    @State private var viewModel = ChatViewModel()  // @State creates it
    
    var body: some View {
        // viewModel properties are tracked automatically
        List(viewModel.messages) { msg in
            MessageRow(message: msg)
        }
    }
}

// Passing down (no @EnvironmentObject needed for simple cases)
struct ChildView: View {
    var viewModel: ChatViewModel  // passed as parameter, changes tracked
    ...
}
```

**@Bindable** (Swift 5.9+): use when you need a binding to a property of an `@Observable` class:

```swift
struct EditView: View {
    @Bindable var viewModel: ChatViewModel
    var body: some View {
        TextField("Message", text: $viewModel.inputText)
    }
}
```

### @ObservableObject (Swift 5.5–5.8) — OLDER pattern

```swift
// OLDER — still works but prefer @Observable
class ChatViewModelOld: ObservableObject {
    @Published var messages: [ChatMessage] = []
}

struct ChatViewOld: View {
    @StateObject private var viewModel = ChatViewModelOld()
    // ...
}
```

**Expectation gap**: LLMs trained on older data will suggest `ObservableObject` + `@Published` + `@StateObject`. In Swift 5.9+ / Xcode 15+, `@Observable` is the correct pattern.

### @Environment — system-provided values

```swift
struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View { ... }
}
```

---

## 4. Async Tasks in Views

### .task modifier (preferred)

```swift
struct DataView: View {
    @State private var data: [Item] = []
    
    var body: some View {
        List(data) { item in ItemRow(item: item) }
        .task {
            // Runs when view appears; auto-cancelled when view disappears
            do {
                data = try await fetchItems()
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
```

### Streaming from AsyncSequence in a View

```swift
struct StreamingView: View {
    @State private var output = ""
    
    var body: some View {
        ScrollView {
            Text(output)
        }
        .task {
            do {
                let stream = client.stream(request)
                for try await event in stream {
                    if event.type == "content_block_delta",
                       let delta = event.delta,
                       delta.type == "text_delta",
                       let text = delta.text {
                        // Update MUST happen on MainActor
                        await MainActor.run {
                            output += text
                        }
                        // OR: mark ChatViewModel @MainActor and mutate directly
                    }
                }
            } catch {
                print(error)
            }
        }
    }
}
```

**Key rule**: SwiftUI view updates must happen on the main thread. When consuming an `AsyncThrowingStream` from a background task, wrap mutations in `await MainActor.run { }` or route through a `@MainActor`-isolated `@Observable` view model.

### @MainActor view model pattern (cleanest for streaming)

```swift
@Observable
@MainActor
class StreamingViewModel {
    var output = ""
    var isStreaming = false
    
    private let client = AnthropicClient()
    
    func stream(prompt: String) async {
        isStreaming = true
        output = ""
        defer { isStreaming = false }
        
        let request = MessagesRequest(model: "claude-sonnet-4-5", messages: [...], maxTokens: 1024)
        do {
            for try await event in client.stream(request) {
                if event.type == "content_block_delta",
                   let text = event.delta?.text {
                    output += text  // safe: @MainActor
                }
            }
        } catch {
            output = "Error: \(error)"
        }
    }
}
```

---

## 5. Portable Cross-Platform View Subset

The following SwiftUI views and modifiers work on both macOS 12+ and iOS 15+ without `#if`:

```swift
// Views
Text("Hello"), Image(systemName: "star"), Button("OK") { }
VStack, HStack, ZStack, Group, ForEach, List, ScrollView
NavigationStack, NavigationLink  // (iOS 16+, macOS 13+)
TextField, SecureField, TextEditor
Divider, Spacer, Color, Rectangle, Circle
ProgressView(), ProgressView(value:, total:)

// Modifiers (most common)
.font(), .foregroundStyle(), .background()
.padding(), .frame(), .cornerRadius()
.disabled(), .opacity(), .hidden()
.task { }, .onAppear { }, .onDisappear { }
.toolbar { }, .navigationTitle()
.alert(isPresented:) { }
.sheet(isPresented:) { }
```

### Platform-specific (require #if)

```swift
// macOS only
#if os(macOS)
.windowStyle(.hiddenTitleBar)
NSViewRepresentable  // bridge to AppKit
NSHostingView
#endif

// iOS only  
#if os(iOS)
UIViewRepresentable  // bridge to UIKit
NavigationView       // deprecated in iOS 16, prefer NavigationStack
.navigationBarTitleDisplayMode()
#endif
```

---

## 6. NavigationStack (macOS 13+ / iOS 16+)

```swift
struct ContentView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            List(items) { item in
                NavigationLink(item.name, value: item)
            }
            .navigationTitle("Chat History")
            .navigationDestination(for: ChatSession.self) { session in
                ChatView(session: session)
            }
        }
    }
}
```

---

## 7. SwiftPM Multiplatform Package Structure

For sharing code between macOS (L5) and iOS (L6) targets:

```swift
// Package.swift for the shared library
// swift-tools-version: 6.1
let package = Package(
    name: "ChatCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ChatCore", targets: ["ChatCore"]),
    ],
    targets: [
        .target(
            name: "ChatCore",
            // No platform-specific imports here
        ),
    ]
)
```

**What goes in the shared library**: `AnthropicClient`, `MessagesRequest/Response` types, `ChatMessage` model, `StreamEvent` types.

**What stays platform-specific**: SwiftUI views, `@main App` struct, AppKit/UIKit bridges.

### Consuming the shared package in an Xcode project

In Xcode: File > Add Package Dependencies > paste GitHub/local URL.

The package resolves to the same `Package.resolved` as SwiftPM CLI. Shared library targets appear as importable modules in the Xcode project.

---

## 8. CLT-Only Build — What Works

**Verified with runtime probe** on macOS 15 + Swift 6.1.2 CLT:

```swift
import SwiftUI

@main
struct TestApp: App {
    var body: some Scene {
        WindowGroup { Text("Hello") }
    }
}
```

Build result: `Build complete! (34.67s)` — exit 0.

**However**: CLT-only builds cannot:
- Launch or run macOS SwiftUI apps (no `open` to run the bundle, no signing)
- Build or run iOS apps (no simulator)
- Sign apps (no provisioning infrastructure)

For actual running and debugging, Xcode is needed. CLT-only is useful for `swift build` CI checks on macOS.

---

## 9. Minimum Xcode Version for Current APIs

| API / Feature | Minimum Xcode | Minimum OS |
|--------------|---------------|------------|
| `@Observable` macro | Xcode 15 | macOS 14 / iOS 17 |
| `NavigationStack` | Xcode 14 | macOS 13 / iOS 16 |
| `.task` modifier | Xcode 13 | macOS 12 / iOS 15 |
| Swift 6 language mode | Xcode 16 | — |
| Swift 6.1 | Xcode 16.3 | — |

For this POC stack targeting macOS 15 / iOS 18: **Xcode 16.3** (ships Swift 6.1.2).

---

## 10. Failure Modes

### FM-1: "use of unresolved identifier" when SwiftUI is imported

**Cause**: file is in a library target (not an app target) and tries to import SwiftUI — SwiftUI is available but some APIs require a running app process.

**Fix**: ensure SwiftUI code is in an app target with proper platform declarations.

### FM-2: Platform declaration mismatch

**Error**: `'SomeView' is only available in macOS 14 or newer`

**Fix**: add `.macOS(.v14)` to platforms, or wrap with `if #available(macOS 14, *)`.

### FM-3: Entitlement issues in sandboxed macOS apps

Accessing network (`URLSession`), reading files outside sandbox, etc., requires entitlements in the `.entitlements` file. CLT builds may not enforce sandbox; Xcode builds do.

**Fix**: add `com.apple.security.network.client` entitlement for outbound network access.

### FM-4: Updating UI from non-main thread

**Error** (runtime, not compile): `[Assert] Main Thread Checker: UI API called on a background thread`

**Fix**: route all `@State` / `@Observable` mutations through `@MainActor`.

### FM-5: @Observable requires Xcode 15 / macOS 14 deployment target

**Error**: `@Observable requires macOS 14`

**Fix**: either raise deployment target OR fall back to `ObservableObject`.

### FM-6: SwiftUI previews not available in CLT

SwiftUI previews (`#Preview`) require Xcode. CLT builds skip preview synthesis entirely — this is not an error, just a limitation to document.

### FM-7: NavigationView deprecated

`NavigationView` is deprecated since iOS 16 / macOS 13. Using it triggers deprecation warnings and inconsistent behavior. Use `NavigationStack` for new code.

---

## 11. iOS Keyboard Avoidance

On iOS, the keyboard obscures bottom content. Add `.ignoresSafeArea(.keyboard)` or use the `.scrollDismissesKeyboard()` modifier:

```swift
ScrollView {
    // chat messages
}
.safeAreaInset(edge: .bottom) {
    // input bar — stays above keyboard
    MessageInputView()
}
```

---

## Sources

- Runtime probe `/tmp/swift-research-probe/swiftui-test/` — SwiftUI + @main builds with CLT, exit 0 (34.67s)
- Apple SwiftUI App organization docs: https://developer.apple.com/documentation/swiftui/app-organization (accessed via WebFetch 2026-05-16)
- Swift Evolution SE-0395 @Observable: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0395-observability.md
- Xcode 16 release notes (Swift 6.1): implied by toolchain version
- `swift --version` → Apple Swift version 6.1.2, arm64-apple-macosx15.0
