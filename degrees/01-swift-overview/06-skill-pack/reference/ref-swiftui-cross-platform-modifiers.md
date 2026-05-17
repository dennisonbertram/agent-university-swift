# Reference — SwiftUI Cross-Platform Modifiers

[Back to index](../index.md)

## Works on both iOS and macOS (no guard needed)

```swift
.navigationTitle("Title")
.padding()
.frame(minWidth: 300)
.background(Color.gray.opacity(0.1))
.foregroundStyle(.primary)
.font(.body)
.scrollContentBackground(.hidden)
.task { /* async work */ }
.onChange(of: value) { old, new in /* ... */ }
.disabled(condition)
.opacity(0.5)
.cornerRadius(8)
.overlay { /* ... */ }
NavigationStack { /* ... */ }
ScrollView { /* ... */ }
VStack, HStack, ZStack
LazyVStack, LazyHStack
TextField("placeholder", text: $binding, axis: .vertical)
Button("label") { /* action */ }
```

## iOS-only — requires `#if os(iOS)`

```swift
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
.submitLabel(.send)
.keyboardType(.default)
.autocorrectionDisabled()
#endif
```

## macOS-only — requires `#if os(macOS)`

```swift
// Scene modifiers (in the app shell, not the library)
#if os(macOS)
.windowResizability(.contentSize)
Settings { /* Preferences view */ }
MenuBarExtra("Name") { /* ... */ }
#endif
```

## App shells — platform-specific entry

The `@main` struct lives in the platform's app shell (not the shared library). macOS uses `WindowGroup`; iOS wraps the same views in a `NavigationStack`:

```swift
// macOS app shell (Sources/ChatMacApp/ChatMacApp.swift)
@main struct ChatMacApp: App {
    var body: some Scene {
        WindowGroup("Claude Chat") { ContentView(vm: vm) }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}

// iOS app shell (iosApp/ChatIOSApp.swift)
@main struct ChatIOSApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack { ContentView(vm: vm) }
        }
    }
}
```

## Shared view with guards

Put `#if os()` guards at modifier level, not around entire view bodies:

```swift
// Correct: fine-grained guard on a single modifier
public struct InputBar: View {
    public var body: some View {
        TextField("Message…", text: $draft, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            #if os(iOS)
            .submitLabel(.send)         // ← guard only this modifier
            #endif
    }
}

// Avoid: whole-body platform split (leads to duplication)
#if os(iOS)
public var body: some View { /* iOS body */ }
#else
public var body: some View { /* macOS body */ }
#endif
```

Evidence: `patterns/cross-platform-swiftui-guards.md`; `L6-swiftui-ios-app/Sources/ChatCoreShared/Views/`; `01-research/05-swiftui-multiplatform.md §5`.
