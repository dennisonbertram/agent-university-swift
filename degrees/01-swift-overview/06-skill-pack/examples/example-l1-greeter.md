# Example — L1: `Greeter.swift` + swift-testing Tests

[Back to index](../index.md) | POC: `degrees/01-swift-overview/03-pocs/L1-hello-spm/`

## What this example demonstrates

- The minimal SwiftPM library shape with `platforms:` declared.
- swift-testing `@Test` and `#expect` usage.
- Library + thin executable shim pattern.

## `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L1-hello-spm",
    platforms: [.macOS(.v13)],      // required; no swift-testing without this
    products: [
        .library(name: "Greeter", targets: ["Greeter"]),
        .executable(name: "hello-spm", targets: ["hello-spm"]),
    ],
    targets: [
        .target(name: "Greeter"),
        .executableTarget(name: "hello-spm", dependencies: ["Greeter"]),
        .testTarget(name: "GreeterTests", dependencies: ["Greeter"]),
    ]
)
```

Source: `L1-hello-spm/Package.swift:1-18`. Key: `platforms:` is declared immediately — the first thing to add after `swift package init`.

## `Greeter.swift`

```swift
// Sources/Greeter/Greeter.swift
public enum Greeter {
    public static func greet(name: String) -> String {
        let trimmed = String(
            name.trimmingPrefix(while: \.isWhitespace)
                .reversed()
                .drop(while: \.isWhitespace)
                .reversed()
        )
        return trimmed.isEmpty ? "Hello, stranger!" : "Hello, \(trimmed)!"
    }
}
```

Source: `L1-hello-spm/Sources/Greeter/Greeter.swift`. Notes:
- `enum` (no instances) — a namespace for static functions.
- The trim-both-ends idiom: `trimmingPrefix` + `reversed().drop(while:).reversed()` because Swift's `StringProtocol` trims only leading whitespace with `trimmingPrefix`.

## `main.swift` — thin shim

```swift
// Sources/hello-spm/main.swift
import Greeter

let args = CommandLine.arguments
let name = args.count > 1 ? args.dropFirst().joined(separator: " ") : ""
print(Greeter.greet(name: name))
```

Source: `L1-hello-spm/Sources/hello-spm/main.swift`. This is a `main.swift` file (not `@main`) — top-level statements are allowed. All logic is in the library target.

## `GreeterTests.swift`

```swift
// Tests/GreeterTests/GreeterTests.swift
import Testing
@testable import Greeter

@Test("Greet a named person")
func greetNamed() {
    #expect(Greeter.greet(name: "world") == "Hello, world!")
}

@Test("Empty name falls back to 'stranger'")
func greetEmpty() {
    #expect(Greeter.greet(name: "") == "Hello, stranger!")
}

@Test("Whitespace-only name falls back to 'stranger'")
func greetWhitespace() {
    #expect(Greeter.greet(name: "   ") == "Hello, stranger!")
}
```

Source: `L1-hello-spm/Tests/GreeterTests/GreeterTests.swift:1-22`. Three test cases cover named, empty, and whitespace-only inputs.

## What to notice

1. `@testable import` allows testing `internal` symbols of `Greeter`.
2. `@Test` functions can be top-level (no enclosing `@Suite` needed).
3. `#expect` is non-fatal — the test function continues on failure, reporting all failures.
4. No `import XCTest`. No `class FooTests: XCTestCase`. This is pure swift-testing.
