# Lesson 1 — Swift Toolchain and SwiftPM

[Back to index](../index.md) | Next: [Lesson 2](lesson-02-swift6-concurrency.md)

## Goal

After this lesson you can scaffold a SwiftPM library, add `platforms:`, write swift-testing tests, and understand the library-vs-executable split.

## Prerequisites

None. This is the first lesson.

## Concepts

### 1.1 Toolchain verification

```bash
swift --version
# Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)
```

The corpus requires Swift 6.1+. All seven POCs use `swift-tools-version: 6.1`, which enables Swift 6 language mode by default (strict concurrency).

### 1.2 Package types

`swift package init --type <type>` emits a skeleton manifest. The two useful types:

| `--type` | What it creates | Entry point |
|----------|----------------|-------------|
| `library` | Library target + test target | n/a |
| `executable` | Executable target | `Sources/<name>/main.swift` |

The L1 POC combines both: a `library` target (`Greeter`) and a thin executable (`hello-spm`) that imports it.

**Pattern — library + thin executable shim:**
```
Sources/
  Greeter/          # library target
    Greeter.swift
  hello-spm/        # executable target
    main.swift      # one-liner: imports Greeter, calls Greeter.greet(...)
Tests/
  GreeterTests/     # test target
    GreeterTests.swift
```

This matters because you cannot `@testable import` an executable target — all testable code lives in the library.

Evidence: `L1-hello-spm/Package.swift:1-18`; `L1-hello-spm/Sources/hello-spm/main.swift`.

### 1.3 The `platforms:` gotcha

`swift package init` generates a `Package.swift` with **no** `platforms:` declaration. Without it, swift-testing macros fail:

```
error: 'isolation()' is only available in macOS 10.15 or newer
@__swiftmacro_13lib_testTests7example4TestfMp_.swift:3:65
```

The fix is to add `platforms:` before the first `swift test`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MyLib",
    platforms: [.macOS(.v13)],          // required
    products: [.library(name: "MyLib", targets: ["MyLib"])],
    targets: [
        .target(name: "MyLib"),
        .testTarget(name: "MyLibTests", dependencies: ["MyLib"])
    ]
)
```

Pin the minimum macOS version your code actually needs. The corpus uses:
- L1: `.macOS(.v13)` — minimal library
- L4 Hummingbird: `.macOS(.v14)` — Hummingbird 2 requirement
- L5/L6 SwiftUI: `.macOS(.v14)` — `@Observable` requires macOS 14

Evidence: `L1-hello-spm/Package.swift:6`; distillation `gotchas/swift-package-init-omits-platforms.md`.

### 1.4 swift-testing basics

swift-testing ships bundled with Swift 6. No package dependency needed.

```swift
import Testing
@testable import MyLib

// A single test function
@Test("Greet a named person")
func greetNamed() {
    #expect(Greeter.greet(name: "world") == "Hello, world!")
}

// Test that throws: use #require to unwrap optionals
@Test("Parse valid JSON")
func parseJSON() throws {
    let data = Data(#"{"name":"Alice"}"#.utf8)
    let decoded = try JSONDecoder().decode([String: String].self, from: data)
    let name = try #require(decoded["name"])
    #expect(name == "Alice")
}

// Grouped tests share a @Suite
@Suite("Greeter suite")
struct GreeterTests {
    @Test("Named") func named() { #expect(Greeter.greet(name: "Bob") == "Hello, Bob!") }
    @Test("Empty") func empty() { #expect(Greeter.greet(name: "") == "Hello, stranger!") }
}
```

Evidence: `L1-hello-spm/Tests/GreeterTests/GreeterTests.swift:1-22`.

### 1.5 Building and running

```bash
swift build                  # compile everything
swift test                   # compile + run tests
swift run <executable-name>  # compile + run an executable target
swift run <exec> arg1 arg2   # pass arguments
```

### 1.6 Sibling SwiftPM dependencies

When L3, L4, L5, L6 depend on L2's `AnthropicClient`, they declare it as a local path dependency:

```swift
dependencies: [
    .package(path: "../L2-anthropic-client"),
],
targets: [
    .target(name: "MyTarget",
            dependencies: [.product(name: "AnthropicClient", package: "L2-anthropic-client")])
]
```

This works for local development. For Docker and production, the path must be replaced with a versioned URL dependency. See [recipe-dockerfile-swift-server.md](../recipes/recipe-dockerfile-swift-server.md) for the caveat.

## Walkthrough — L1 Package Layout

```
L1-hello-spm/
  Package.swift                        # swift-tools-version: 6.1, platforms: macOS 13
  Sources/
    Greeter/
      Greeter.swift                    # public enum Greeter { public static func greet... }
    hello-spm/
      main.swift                       # import Greeter; print(Greeter.greet(name: ...))
  Tests/
    GreeterTests/
      GreeterTests.swift               # import Testing; @Test; #expect(...)
```

Key facts from the POC:
- `Greeter` is an `enum` (no instances, just a namespace for static functions) — a valid Swift idiom for utility types.
- `main.swift` is intentionally minimal. All logic lives in `Greeter/`.
- Tests use `@testable import MyLib` to access `internal` symbols.

## Pitfalls

- **Missing `platforms:`** → `swift test` fails. Fix: always add `platforms: [.macOS(.v13)]` or higher. See [ts-swift-test-fails-without-platforms.md](../troubleshooting/ts-swift-test-fails-without-platforms.md).
- **Two entry points** (`main.swift` + `@main`) → compile error. See [lesson-06-cli-tools-with-argument-parser.md](lesson-06-cli-tools-with-argument-parser.md) for the rule.
- **Putting test-observable code in the executable target** → you cannot `@testable import` it. Keep logic in library targets.

## Exercise

Complete [lab-01-hello-spm.md](../labs/lab-01-hello-spm.md): build a `FizzBuzz` library from scratch with swift-testing tests.

## Recap

- `swift package init` emits an incomplete manifest — always add `platforms:` immediately.
- Library targets are testable; executable targets are entry points only.
- swift-testing (`@Test`, `#expect`, `#require`, `@Suite`) is bundled with Swift 6.
- Sibling packages reference each other via `.package(path: "../<sibling>")`.
