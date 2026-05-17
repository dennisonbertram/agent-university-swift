# Assessment 5 — SwiftUI Multiplatform

[Back to index](../index.md) | Covers: [lesson-08-swiftui-macos-app.md](../lessons/lesson-08-swiftui-macos-app.md), [lesson-09-multiplatform-swift-packages.md](../lessons/lesson-09-multiplatform-swift-packages.md)

## Questions

**Q1.** In Swift 5.9+ SwiftUI, replace these old patterns with the new equivalents:

```swift
class MyViewModel: ObservableObject {
    @Published var count: Int = 0
}
struct MyView: View {
    @StateObject var vm = MyViewModel()
}
```

**Q2.** You have a `ChatViewModel` in a shared library with `import SwiftUI` at the top. Why is this a problem for a multiplatform package, and what should you import instead?

**Q3.** You want to add `.navigationBarTitleDisplayMode(.inline)` to a shared view. This modifier is iOS-only. How do you add it without breaking the macOS build?

**Q4.** `swift build` exits 0 on your Mac. You open the package in Xcode and try to build for the iOS simulator — it fails with `cannot find 'NSView' in scope`. Where did `NSView` appear, and why didn't `swift build` catch it?

**Q5.** You have a `@MainActor @Observable ChatViewModel`. How do you write a swift-testing test suite for it? Why must the suite be `@MainActor`?

<details>
<summary>Answer Key</summary>

**A1.** New equivalents:
```swift
@Observable
final class MyViewModel {
    var count: Int = 0
}
struct MyView: View {
    @State private var vm = MyViewModel()    // @State instead of @StateObject
}
// For child views that need two-way bindings:
struct ChildView: View {
    @Bindable var vm: MyViewModel            // @Bindable instead of @ObservedObject
}
```

**A2.** `import SwiftUI` in the view model ties it to the SwiftUI framework. On iOS, SwiftUI is available; on the macOS CLI build with Command Line Tools, SwiftUI is present but the view model shouldn't carry framework-level coupling. More importantly: the architecturally correct split is view model (business logic) vs view (display). The view model should import only `Foundation` and `Observation`. The `@Observable` macro comes from `Observation`, not `SwiftUI`.

**A3.** Use a `#if os(iOS)` guard at modifier level:
```swift
.navigationTitle("Claude")
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
```
Apply the guard to just the one modifier, not to the entire view body.

**A4.** `swift build` on macOS compiles only the macOS target. `import AppKit` (which exposes `NSView`) is macOS-only and compiles fine. When Xcode builds for iOS, `AppKit` is not available — the error surfaces. To detect this earlier: add `.iOS(.v17)` to `platforms:`, and verify with Xcode's iOS scheme.

**A5.**
```swift
@MainActor
@Suite("ChatViewModel")
struct ChatViewModelTests {
    @Test("count increments") func increment() {
        let vm = ChatViewModel(service: MockLLMService())
        vm.increment()
        #expect(vm.count == 1)
    }
}
```
The suite must be `@MainActor` because `ChatViewModel` is `@MainActor`. Without `@MainActor` on the suite, accessing `vm.count` from a non-`MainActor` context would be a Swift 6 concurrency error.

</details>
