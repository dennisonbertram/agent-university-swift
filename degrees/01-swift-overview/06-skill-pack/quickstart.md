# Quickstart — Get a Green Test in 10 Minutes

This is a linear path. Follow each step in order. At the end you will have a SwiftPM library with a passing swift-testing test.

[Back to index](index.md) | Next: [Lesson 1](lessons/lesson-01-swift-toolchain-and-swiftpm.md)

---

## Step 1 — Verify the toolchain

```bash
swift --version
```

Expected output (or newer):
```
Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)
```

If you see Swift 5.x, stop. The corpus requires Swift 6.1+. Install from [swift.org/install](https://www.swift.org/install/).

No Xcode required for this quickstart. Command Line Tools is sufficient for libraries and CLIs.

---

## Step 2 — Scaffold a SwiftPM package

```bash
mkdir MyLib && cd MyLib
swift package init --type library
```

SwiftPM creates `Package.swift`, `Sources/MyLib/MyLib.swift`, and `Tests/MyLibTests/MyLibTests.swift`.

**Important:** The generated `Package.swift` is incomplete. Proceed to Step 3 before running anything.

---

## Step 3 — Add `platforms:` to `Package.swift`

Open `Package.swift`. The generated file has no `platforms:` declaration. Without it, `swift test` fails immediately with:

```
error: 'isolation()' is only available in macOS 10.15 or newer
```

Edit the file to match:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MyLib",
    platforms: [.macOS(.v13)],          // <-- add this line
    products: [
        .library(name: "MyLib", targets: ["MyLib"]),
    ],
    targets: [
        .target(name: "MyLib"),
        .testTarget(name: "MyLibTests", dependencies: ["MyLib"]),
    ]
)
```

This gotcha affects every new package. See [ts-swift-test-fails-without-platforms.md](troubleshooting/ts-swift-test-fails-without-platforms.md) for the full explanation.

---

## Step 4 — Write a library function

Replace the contents of `Sources/MyLib/MyLib.swift`:

```swift
public enum Greeter {
    public static func greet(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Hello, stranger!" : "Hello, \(trimmed)!"
    }
}
```

Evidence: `L1-hello-spm/Sources/Greeter/Greeter.swift` uses the same structure.

---

## Step 5 — Write a swift-testing test

Replace the contents of `Tests/MyLibTests/MyLibTests.swift`:

```swift
import Testing
@testable import MyLib

@Test("Greet a named person")
func greetNamed() {
    #expect(Greeter.greet(name: "world") == "Hello, world!")
}

@Test("Empty name falls back to 'stranger'")
func greetEmpty() {
    #expect(Greeter.greet(name: "") == "Hello, stranger!")
}
```

`import Testing` requires no package dependency — swift-testing ships bundled with Swift 6.

---

## Step 6 — Run the tests

```bash
swift build    # exit 0
swift test     # all tests pass
```

Expected output:
```
◇ Test run started.
↳ Testing Library Version: 124.4
✔ Test "Greet a named person" passed after 0.001 seconds.
✔ Test "Empty name falls back to 'stranger'" passed after 0.001 seconds.
✔ Test run with 2 tests passed after 0.001 seconds.
```

If `swift test` fails with the `isolation()` error, you missed Step 3. Add `platforms:` and retry.

---

## What you just learned

- `swift package init` emits an incomplete manifest — always add `platforms:`.
- swift-testing (`@Test`, `#expect`) is bundled with Swift 6; no dependency needed.
- `swift build` + `swift test` is the entire local feedback loop.

---

## Next steps

- **Lesson 1** — deeper coverage of SwiftPM structure: [lesson-01-swift-toolchain-and-swiftpm.md](lessons/lesson-01-swift-toolchain-and-swiftpm.md)
- **Lesson 2** — Swift 6 concurrency, Sendable, actors: [lesson-02-swift6-concurrency.md](lessons/lesson-02-swift6-concurrency.md)
- **Agent:** load [ai-system-prompt-swift.md](agent-instructions/ai-system-prompt-swift.md) before writing real Swift code.
