# Lab 1 — Hello SwiftPM

[Back to index](../index.md) | Lesson: [lesson-01-swift-toolchain-and-swiftpm.md](../lessons/lesson-01-swift-toolchain-and-swiftpm.md)

## Task

Build a SwiftPM library that exposes a `fizzbuzz(n:)` function and test it with swift-testing.

## Deliverables

- `Sources/FizzBuzz/FizzBuzz.swift` — public function
- `Tests/FizzBuzzTests/FizzBuzzTests.swift` — at least 4 `@Test` cases
- `swift test` exits 0

## Starter `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FizzBuzz",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FizzBuzz", targets: ["FizzBuzz"]),
    ],
    targets: [
        .target(name: "FizzBuzz"),
        .testTarget(name: "FizzBuzzTests", dependencies: ["FizzBuzz"]),
    ]
)
```

## Stub source

```swift
// Sources/FizzBuzz/FizzBuzz.swift
public enum FizzBuzz {
    public static func result(for n: Int) -> String {
        // TODO: implement
        return ""
    }
}
```

## Expected behaviour

| Input | Output |
|-------|--------|
| 1 | `"1"` |
| 3 | `"Fizz"` |
| 5 | `"Buzz"` |
| 15 | `"FizzBuzz"` |
| -1 | your choice |

## Required test cases

Write at least:
- `@Test("divisible by 3 only → Fizz")`
- `@Test("divisible by 5 only → Buzz")`
- `@Test("divisible by 15 → FizzBuzz")`
- `@Test("not divisible → numeral string")`

## Verification

```bash
swift test
# All tests pass
```

<details>
<summary>Hint</summary>

`n % 15 == 0` catches FizzBuzz before the individual 3 and 5 checks. Check 15 first.

```swift
public static func result(for n: Int) -> String {
    switch (n % 3 == 0, n % 5 == 0) {
    case (true, true):  return "FizzBuzz"
    case (true, false): return "Fizz"
    case (false, true): return "Buzz"
    case (false, false): return "\(n)"
    }
}
```

</details>
