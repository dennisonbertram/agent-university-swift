# Lesson 9 — Multiplatform Swift Packages

[Back to index](../index.md) | Prev: [Lesson 8](lesson-08-swiftui-macos-app.md) | Next: [Lesson 10](lesson-10-end-to-end-integration-testing.md)

## Goal

After this lesson you can make a SwiftPM package compile for both iOS and macOS, isolate platform-specific modifiers with `#if os()` guards, and organise the iOS app shell correctly.

## Prerequisites

[Lesson 8](lesson-08-swiftui-macos-app.md) — `@Observable` view model and SwiftUI basics.

## Concepts

### 9.1 `platforms:` declaration for both platforms

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ChatCoreShared",
    platforms: [
        .iOS(.v17),        // @Observable requires iOS 17+
        .macOS(.v14)       // @Observable requires macOS 14+
    ],
    products: [
        .library(name: "ChatCoreShared", targets: ["ChatCoreShared"])
    ],
    targets: [
        .target(name: "ChatCoreShared",
                dependencies: [.product(name: "AnthropicClient", package: "L2-anthropic-client")]),
        .testTarget(name: "ChatCoreSharedTests", dependencies: ["ChatCoreShared"])
    ]
)
```

Evidence: `L6-swiftui-ios-app/Package.swift:5-28`.

### 9.2 What belongs in the shared library

| In the shared library | In the per-platform app shell |
|-----------------------|-------------------------------|
| `ChatViewModel` (no `import SwiftUI`) | `@main struct App: App` |
| `ChatMessage`, `Role`, models | `WindowGroup` / iOS scene root |
| `AnthropicClient` / `BackendLLMService` | App icon, `Info.plist`, entitlements |
| `ChatScreen`, `MessageRow`, `InputBar` (views with `#if` guards) | iOS `.xcodeproj` |
| `LLMService` protocol | Anything needing simulator or Xcode |

Evidence: `patterns/multiplatform-spm-package.md`.

### 9.3 Forbidden imports in shared library targets

The shared library must NOT contain:

```swift
import AppKit        // macOS only
import UIKit         // iOS only
import Combine       // avoid; use Observation
```

The view model imports only `Foundation`, `Observation`, and the LLM client. Views in the shared library may `import SwiftUI`.

Running `swift build` on macOS will not catch `import UIKit` in shared code — that only fails when the Xcode iOS project tries to compile. Run `swift build` to catch `AppKit`; use Xcode to catch `UIKit`.

Evidence: `before-you-build/swiftui-multiplatform.md`; `anti-patterns/import-swiftui-in-viewmodel.md`.

### 9.4 `#if os()` guards — use them tightly

Most SwiftUI views compile unchanged on both platforms. Guard only the specific modifier that diverges:

```swift
public struct ChatScreen: View {
    @Bindable public var vm: ChatViewModel

    public var body: some View {
        VStack(spacing: 0) {
            messagesScroll
            InputBar(draft: $vm.draft, isStreaming: vm.isStreaming,
                     onSend: { /* ... */ }, onCancel: { vm.cancel() })
        }
        .navigationTitle("Claude")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)     // iOS-only modifier
        #endif
    }
}

public struct InputBar: View {
    @Binding public var draft: String
    // ...
    public var body: some View {
        HStack {
            TextField("Message…", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSend)
                #if os(iOS)
                .submitLabel(.send)                 // iOS-only modifier
                #endif
        }
    }
}
```

Guards in the app shell (macOS executable):

```swift
var body: some Scene {
    WindowGroup("Claude Chat") { RootView(vm: vm) }
    #if os(macOS)
    .windowResizability(.contentSize)              // macOS-only scene modifier
    #endif
}
```

**Never put `#if` guards inside the view model.** If you find yourself doing that, the abstraction is wrong.

Evidence: `patterns/cross-platform-swiftui-guards.md`; `L6-swiftui-ios-app/Sources/ChatCoreShared/Views/ChatScreen.swift:27-29`.

### 9.5 iOS app shell strategy

iOS apps cannot be built from `swift build` — they require a `.xcodeproj` and Xcode (or `xcodebuild`). The corpus strategy:

1. Keep iOS source files (the `@main App`, root view) in `iosApp/` outside the SwiftPM target tree.
2. Include an `OPEN-IN-XCODE.md` that walks through: create a new Xcode iOS App project → add the SwiftPM package as a local dependency → drag in the `iosApp/*.swift` source files.
3. Do NOT commit a hand-written `project.pbxproj` — it is fragile and large.

Evidence: `anti-patterns/hand-written-xcodeproj-pbxproj.md`; `decision-records/adr-009-iosapp-source-files-not-xcodeproj.md`.

### 9.6 Regression pin for the invariant

Add a test that fails if `import SwiftUI` ever appears in the view model:

```swift
@Test("REGRESSION-002: ChatViewModel contains no 'import SwiftUI'")
func chatViewModelHasNoSwiftUIImport() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let vmPath = packageRoot.appendingPathComponent("Sources/ChatCoreShared/ChatViewModel.swift")
    let source = try String(contentsOf: vmPath, encoding: .utf8)
    let hasImport = source.components(separatedBy: "\n").contains {
        $0.trimmingCharacters(in: .whitespaces).hasPrefix("import SwiftUI")
    }
    #expect(!hasImport)
}
```

Evidence: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/RegressionTests.swift:60-108`.

### 9.7 Capstone multiplatform structure

The capstone unifies macOS app + iOS shell + Hummingbird backend in one `Package.swift`:

```swift
platforms: [.iOS(.v17), .macOS(.v14)],
products: [
    .library(name: "ChatCore", targets: ["ChatCore"]),
    .executable(name: "chat-backend", targets: ["chat-backend"]),
    .executable(name: "ChatMacApp", targets: ["ChatMacApp"])
],
targets: [
    .target(name: "ChatCore",       // shared: view model + views + LLM service
            dependencies: [.product(name: "AnthropicClient", package: "L2-anthropic-client")]),
    .executableTarget(name: "ChatMacApp", dependencies: ["ChatCore"]),
    .executableTarget(name: "chat-backend",
                      dependencies: ["ChatCore", .product(name: "Hummingbird", package: "hummingbird")])
]
```

`ChatCore` depends on `AnthropicClient` only. The `chat-backend` target adds `Hummingbird`. The iOS app shell in `iosApp/` is added to Xcode separately.

Evidence: `L-capstone-multiplatform-chat/Package.swift:5-64`.

## Pitfalls

- **`import AppKit` in shared code** → the package fails to compile for iOS. See [ts-multiplatform-package-fails-ios-only-api.md](../troubleshooting/ts-multiplatform-package-fails-ios-only-api.md).
- **Missing `platforms:` for iOS** → the package fails with a deployment target error when Xcode tries to use it.
- **Whole-file `#if os()` guards** → duplicated code that diverges. Use fine-grained modifier-level guards instead.
- **Hand-written `.xcodeproj`** → fragile, large, hard to maintain. Store raw `.swift` files instead.

## Exercise

Complete [lab-08-multiplatform-greeter.md](../labs/lab-08-multiplatform-greeter.md): a SwiftPM package targeting iOS+macOS with a shared SwiftUI greeting view.

## Recap

- `platforms: [.iOS(.v17), .macOS(.v14)]` in the shared library.
- No `import AppKit`, `import UIKit`, or `import Combine` in shared targets.
- Guard only specific platform-divergent modifiers with `#if os(iOS)` / `#if os(macOS)`.
- iOS app shell: `.swift` files in `iosApp/` + `OPEN-IN-XCODE.md`. No `.xcodeproj`.
- Regression-pin the `no import SwiftUI in view model` invariant.
