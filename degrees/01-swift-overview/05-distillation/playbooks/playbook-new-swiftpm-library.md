# Playbook: scaffold a new SwiftPM library with swift-testing

**Goal**: From an empty directory to a building/testing library that uses `import Testing` and has a passing test, in under 5 minutes.

## Prerequisites
- Apple Swift 6.1+ (`swift --version`).
- macOS 13+ (the corpus pins macOS 13/14/15 across POCs).
- No Xcode required for libraries.

## Steps

1. Create the directory and run `swift package init`. **Do not** trust the generated `Package.swift`.
   ```bash
   mkdir MyLib && cd MyLib
   swift package init --type library
   ```

2. **Add `platforms:`** to the generated manifest. Without this, `swift test` fails with `'isolation()' is only available in macOS 10.15 or newer`.
   ```swift
   // swift-tools-version: 6.1
   import PackageDescription

   let package = Package(
       name: "MyLib",
       platforms: [.macOS(.v13)],         // <-- REQUIRED
       products: [.library(name: "MyLib", targets: ["MyLib"])],
       targets: [
           .target(name: "MyLib"),
           .testTarget(name: "MyLibTests", dependencies: ["MyLib"])
       ]
   )
   ```

3. Write the library source. Keep it simple:
   ```swift
   // Sources/MyLib/Greeter.swift
   public enum Greeter {
       public static func greet(name: String) -> String {
           let trimmed = String(name.trimmingPrefix(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
           return trimmed.isEmpty ? "Hello, stranger!" : "Hello, \(trimmed)!"
       }
   }
   ```

4. Write the test using `import Testing` (no Package.swift dependency needed — swift-testing ships with Swift 6).
   ```swift
   // Tests/MyLibTests/MyLibTests.swift
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

5. Build and test:
   ```bash
   swift build         # exit 0
   swift test          # "Test run with 2 tests passed"
   ```

## You'll know it worked when…
`swift test` prints something like:
```
◇ Test run started.
↳ Testing Library Version: 124.4
↳ Target Platform: arm64e-apple-macos14.0
✔ Test "Greet a named person" passed
✔ Test "Empty name falls back to 'stranger'" passed
✔ Test run with 2 tests passed
```

## Evidence
- POC: `L1-hello-spm/Package.swift:1-18` — the canonical minimal manifest with `platforms:` set.
- POC: `L1-hello-spm/Sources/Greeter/Greeter.swift:1-13` — library function.
- POC: `L1-hello-spm/Tests/GreeterTests/GreeterTests.swift:1-22` — three `@Test` cases.
- POC: `L1-hello-spm/README.md` — full L1 walkthrough.
- Research: `01-research/02-swiftpm-and-tooling.md` §1, §6 — Package.swift anatomy and swift-testing API.
- See also: gotcha `gotchas/swift-package-init-omits-platforms.md`, before-you-build `before-you-build/swift6-concurrency-task.md`.
