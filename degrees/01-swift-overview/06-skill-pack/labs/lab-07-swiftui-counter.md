# Lab 7 — SwiftUI Counter

[Back to index](../index.md) | Lesson: [lesson-08-swiftui-macos-app.md](../lessons/lesson-08-swiftui-macos-app.md)

## Task

Build a SwiftUI macOS app with an `@Observable` counter view model and view that increments, decrements, and resets a count.

## Deliverables

- `Sources/CounterCore/CounterViewModel.swift` — `@MainActor @Observable` view model
- `Sources/CounterApp/CounterApp.swift` — `@main App` entry point
- `Sources/CounterApp/ContentView.swift` — SwiftUI view with `@Bindable`
- `Tests/CounterCoreTests/CounterViewModelTests.swift` — view model tests
- `swift test` exits 0
- `swift build` exits 0

## Starter `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CounterApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CounterApp", targets: ["CounterApp"]),
        .library(name: "CounterCore", targets: ["CounterCore"]),
    ],
    targets: [
        .target(name: "CounterCore"),
        .executableTarget(name: "CounterApp", dependencies: ["CounterCore"]),
        .testTarget(name: "CounterCoreTests", dependencies: ["CounterCore"]),
    ]
)
```

## Requirements

### `CounterViewModel`

```swift
// Sources/CounterCore/CounterViewModel.swift
// NO import SwiftUI — use import Observation

@MainActor
@Observable
public final class CounterViewModel {
    public private(set) var count: Int = 0

    public init(initial: Int = 0) { count = initial }

    public func increment() { count += 1 }
    public func decrement() { count -= 1 }
    public func reset() { count = 0 }
}
```

### `ContentView`

Show the current count. Provide three buttons: `+`, `-`, `Reset`. The `+` and `-` buttons call the view model's methods.

### App entry point

```swift
// Sources/CounterApp/CounterApp.swift
import SwiftUI
import CounterCore

@main
struct CounterApp: App {
    @State private var vm = CounterViewModel()

    var body: some Scene {
        WindowGroup("Counter") {
            ContentView(vm: vm).frame(width: 300, height: 200)
        }
    }
}
```

## Required tests

```swift
@MainActor
@Suite("CounterViewModel")
struct CounterViewModelTests {
    @Test("Initial count is 0") func initialCount() { /* #expect */ }
    @Test("Increment") func increment() { /* increment twice, #expect count == 2 */ }
    @Test("Decrement") func decrement() { /* decrement from 5, #expect count == 4 */ }
    @Test("Reset") func reset() { /* increment, reset, #expect count == 0 */ }
}
```

## Verification

```bash
swift test         # view model tests pass
swift build        # app compiles
```

Note: `swift run CounterApp` may not show a window from the CLI without Xcode. `swift build` and `swift test` are the verification gates.

<details>
<summary>Hint</summary>

```swift
struct ContentView: View {
    @Bindable var vm: CounterViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("\(vm.count)")
                .font(.system(size: 72, weight: .bold))
            HStack(spacing: 16) {
                Button("-") { vm.decrement() }
                Button("Reset") { vm.reset() }
                Button("+") { vm.increment() }
            }
            .buttonStyle(.bordered)
        }
    }
}
```

</details>
