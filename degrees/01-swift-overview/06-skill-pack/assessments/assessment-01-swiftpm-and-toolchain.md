# Assessment 1 — SwiftPM and Toolchain

[Back to index](../index.md) | Covers: [lesson-01-swift-toolchain-and-swiftpm.md](../lessons/lesson-01-swift-toolchain-and-swiftpm.md)

## Questions

**Q1.** You run `swift package init --type library` and immediately run `swift test`. The error is:
```
error: 'isolation()' is only available in macOS 10.15 or newer
```
What is the cause, and what is the one-line fix?

**Q2.** You want to write testable library code and expose it as a CLI. What is the correct SwiftPM structure? Choose one:
- (A) Put all code in `Sources/MyApp/main.swift`
- (B) Put logic in a library target (`Sources/MyLib/`) and a thin executable target (`Sources/myapp/main.swift`) that imports it
- (C) Put tests in the executable target and `@testable import` the executable

**Q3.** What is the difference between `@Test func foo()` and `class FooTests: XCTestCase`? In a Swift 6 package, which do you use and why?

**Q4.** You have two sibling packages at `../L2-anthropic-client` and `../L3-cli-chat`. Write the `dependencies:` and target dependency for L3 to consume L2's `AnthropicClient` product.

**Q5.** You are building a Hummingbird service. What `platforms:` value do you need and why?

<details>
<summary>Answer Key</summary>

**A1.** Cause: the generated `Package.swift` has no `platforms:` declaration. SwiftPM defaults to an old deployment target; swift-testing's `#isolation` macro requires macOS 10.15+. Fix: add `platforms: [.macOS(.v13)]` (or higher) to `Package.swift` before running anything.

**A2.** (B). Executable targets cannot be `@testable import`-ed. All testable logic belongs in a library target. The executable target is a thin shim that imports the library.

**A3.** `@Test func foo()` is swift-testing (bundled with Swift 6, no package dependency). `class FooTests: XCTestCase` is XCTest (older, requires Xcode infrastructure for some features). In a Swift 6 package, use `@Test` / `#expect` / `#require`. No `import XCTest` needed.

**A4.**
```swift
dependencies: [
    .package(path: "../L2-anthropic-client"),
],
targets: [
    .target(name: "ChatCore",
            dependencies: [.product(name: "AnthropicClient", package: "L2-anthropic-client")])
]
```

**A5.** `platforms: [.macOS(.v14)]`. Hummingbird 2.x requires macOS 14+. (If the package also targets iOS, add `.iOS(.v17)`.)

</details>
