# Lab 8 — Multiplatform Greeter

[Back to index](../index.md) | Lesson: [lesson-09-multiplatform-swift-packages.md](../lessons/lesson-09-multiplatform-swift-packages.md)

## Task

Build a SwiftPM package targeting iOS 17+ and macOS 14+ with a shared SwiftUI greeting view and platform-specific adjustments.

## Deliverables

- `Package.swift` — `platforms: [.iOS(.v17), .macOS(.v14)]`
- `Sources/GreeterCore/GreeterViewModel.swift` — `@Observable`, no `import SwiftUI`
- `Sources/GreeterCore/Views/GreeterView.swift` — shared SwiftUI view with `#if os(iOS)` guard
- `Tests/GreeterCoreTests/GreeterViewModelTests.swift` — view model tests
- `Sources/GreeterMacApp/GreeterMacApp.swift` — macOS `@main App`
- `iosApp/GreeterIOSApp.swift` — iOS app shell source (not part of SPM target)
- `iosApp/OPEN-IN-XCODE.md` — instructions to add to Xcode iOS project
- `swift test` exits 0
- `swift build` exits 0

## Starter `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MultiGreeter",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "GreeterCore", targets: ["GreeterCore"]),
        .executable(name: "GreeterMacApp", targets: ["GreeterMacApp"]),
    ],
    targets: [
        .target(name: "GreeterCore"),
        .executableTarget(name: "GreeterMacApp", dependencies: ["GreeterCore"]),
        .testTarget(name: "GreeterCoreTests", dependencies: ["GreeterCore"]),
    ]
)
```

## Requirements

### `GreeterViewModel`

```swift
// Sources/GreeterCore/GreeterViewModel.swift
// NO import SwiftUI, NO import AppKit, NO import UIKit

import Observation

@MainActor
@Observable
public final class GreeterViewModel {
    public var name: String = ""
    public var greeting: String { name.isEmpty ? "Hello, stranger!" : "Hello, \(name)!" }

    public init() {}
}
```

### `GreeterView` (shared)

```swift
// Sources/GreeterCore/Views/GreeterView.swift
import SwiftUI

public struct GreeterView: View {
    @Bindable public var vm: GreeterViewModel

    public init(vm: GreeterViewModel) { self.vm = vm }

    public var body: some View {
        VStack(spacing: 16) {
            TextField("Your name", text: $vm.name)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .submitLabel(.done)          // iOS-only modifier
                #endif
            Text(vm.greeting)
                .font(.title)
        }
        .padding()
        .navigationTitle("Greeter")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)    // iOS-only
        #endif
    }
}
```

### macOS app shell

```swift
// Sources/GreeterMacApp/GreeterMacApp.swift
import SwiftUI
import GreeterCore

@main
struct GreeterMacApp: App {
    @State private var vm = GreeterViewModel()
    var body: some Scene {
        WindowGroup("Greeter") {
            NavigationStack { GreeterView(vm: vm) }.frame(width: 300, height: 200)
        }
    }
}
```

### iOS app shell (`iosApp/`)

Create `iosApp/GreeterIOSApp.swift` and `iosApp/OPEN-IN-XCODE.md`. These files are NOT part of any SPM target. They are Xcode-ready source files.

## Required tests

```swift
@MainActor
@Suite("GreeterViewModel")
struct GreeterViewModelTests {
    @Test("Empty name → 'Hello, stranger!'") func emptyName() { /* ... */ }
    @Test("Named → 'Hello, <name>!'") func named() { /* ... */ }
}
```

Also add a regression test that the view model contains no `import SwiftUI`.

## Verification

```bash
swift test    # view model tests pass + no-SwiftUI-import regression
swift build   # GreeterCore + GreeterMacApp compile for macOS
```

<details>
<summary>Hint for OPEN-IN-XCODE.md</summary>

```markdown
# Opening GreeterIOSApp in Xcode

1. Open Xcode. File → New → Project → iOS App.
2. Name it "GreeterIOS".
3. File → Add Package Dependencies → Add Local → select the `MultiGreeter` directory.
4. Add the `GreeterCore` library as a dependency.
5. Delete the Xcode template's ContentView.swift.
6. Drag `iosApp/GreeterIOSApp.swift` into the Xcode project.
7. Build for the iOS Simulator.
```

</details>
