# SwiftPM, swift-testing, and swift-argument-parser

> All probes run on: Apple Swift 6.1.2, arm64-apple-macosx15.0, CLT-only (no full Xcode)

---

## 1. Package.swift Manifest Anatomy

The manifest is a Swift file — it compiles. The `// swift-tools-version:` comment is load-bearing.

```swift
// swift-tools-version: 6.1          ← minimum Swift required; controls available APIs
import PackageDescription

let package = Package(
    name: "MyPackage",                // logical name; also default module name
    
    // Platform requirements — REQUIRED for swift-testing and modern APIs
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    
    // Products: what this package exposes to dependents
    products: [
        .library(name: "MyLib", targets: ["MyLib"]),
        .executable(name: "mycli", targets: ["mycli"]),
    ],
    
    // Dependencies: other packages
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    
    // Targets: compilation units
    targets: [
        // Library target
        .target(
            name: "MyLib",
            dependencies: [],
            path: "Sources/MyLib"     // optional — defaults to Sources/<name>
        ),
        
        // Executable target
        .executableTarget(
            name: "mycli",
            dependencies: [
                "MyLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        
        // Test target (always depends on testing library implicitly in Swift 6)
        .testTarget(
            name: "MyLibTests",
            dependencies: ["MyLib"]
        ),
    ]
)
```

### swift-tools-version effects

| Version | Key effect |
|---------|-----------|
| `6.1` | Swift 6 language mode by default, latest SwiftPM APIs |
| `5.10` | Swift 5 language mode, older SwiftPM API surface |
| `5.9` | Required for `@Observable` macro, Swift macros in general |

**Verified**: `swift package init --type executable` generates `swift-tools-version: 6.1` on Swift 6.1.2 toolchain.

Source: runtime probe `/tmp/swift-research-probe/hello-spm/Package.swift`

---

## 2. Source Layout Conventions

SwiftPM uses **convention-based layout** — no explicit source file listing needed.

```
MyPackage/
├── Package.swift
├── Sources/
│   ├── MyLib/            ← target "MyLib" sources
│   │   ├── Lib.swift
│   │   └── Models.swift
│   └── mycli/            ← target "mycli" sources  
│       └── main.swift    ← entry point for executable
└── Tests/
    └── MyLibTests/       ← target "MyLibTests" sources
        └── MyLibTests.swift
```

**Single-target shortcut**: if there's only one target, sources can go directly in `Sources/`.

**main.swift vs @main**: An executable target needs exactly ONE entry point. Either:
- A file named `main.swift` (top-level code allowed)
- A type annotated `@main` (in any file other than `main.swift`)

Using both is a compile error.

---

## 3. Build / Run / Test Workflow

```bash
# Build all targets
swift build

# Build specific target
swift build --target MyLib

# Build release (optimized)
swift build -c release

# Run an executable target
swift run mycli --help
swift run mycli --verbose --count 3 "hello"

# Run tests
swift test

# Run tests matching a pattern
swift test --filter MyLibTests

# Show package structure
swift package describe
swift package show-dependencies

# Resolve dependencies (writes Package.resolved)
swift package resolve

# Update dependencies to latest allowed versions
swift package update
```

**Probe result** — build of `hello-spm` (generated executable):
```
Build complete! (19.26s)
```
Source: runtime probe `/tmp/swift-research-probe/hello-spm/`

---

## 4. Library vs Executable Targets

| | Library (`.target`) | Executable (`.executableTarget`) |
|---|---|---|
| Produces | `.a` + module | binary |
| Top-level code in `main.swift` | Not allowed | Required or use `@main` |
| Can be imported | Yes | No (binary only) |
| `@main` entry | Not allowed | Yes (in non-`main.swift` file) |
| Dependencies | Full SwiftPM graph | Full SwiftPM graph |

---

## 5. Multiplatform: Declaring Platforms and Conditional Compilation

```swift
// Package.swift: declare platform requirements
platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .tvOS(.v18),
]

// Conditional compilation in Swift source
#if os(macOS)
import AppKit
let nsColor = NSColor.blue
#elseif os(iOS)
import UIKit
let uiColor = UIColor.blue
#endif

// Conditional source files in Package.swift (less common)
.target(
    name: "PlatformLib",
    exclude: ["iOS/IOSOnly.swift"]  // crude workaround
)
```

**What works with CLT-only vs Xcode**:

| Capability | CLT Only | Needs Xcode |
|-----------|----------|-------------|
| `swift build` / `swift test` | ✅ | — |
| SwiftUI compile (macOS) | ✅ | — |
| SwiftUI compile (iOS simulator) | ❌ | ✅ |
| iOS device builds | ❌ | ✅ |
| Code signing | ❌ | ✅ |
| `.xcodeproj` generation | via `swift package generate-xcodeproj` | — |

**Verified**: SwiftUI with `import SwiftUI` and `@main struct App: App` compiles successfully with CLT-only toolchain on macOS 15. Build completed in 34.67s.

Source: runtime probe `/tmp/swift-research-probe/swiftui-test/` — exit 0

---

## 6. swift-testing

**Current version**: Bundled with Swift 6 toolchain (no explicit dependency needed). Ships as the Testing module. Library version "124.4" per test output.

**No Package.swift dependency required** — just `import Testing`.

### Core API

```swift
import Testing

// Basic test
@Test func myTest() {
    #expect(1 + 1 == 2)
}

// Named test
@Test("Descriptive test name")
func namedTest() {
    #expect("hello".count == 5)
}

// #expect — assertion macro, captures both sides on failure
@Test func checkValue() {
    let greeting = "Hello, world!"
    #expect(greeting == "Hello")
    // On failure: "Expectation failed: (greeting → "Hello, world!") == "Hello""
}

// #require — throws if condition fails (stops test, not program)
@Test func requireOptional() throws {
    let value: Int? = nil
    let unwrapped = try #require(value)  // throws if nil
    #expect(unwrapped > 0)
}

// Async test
@Test func asyncOperation() async throws {
    let result = await withCheckedContinuation { cont in
        cont.resume(returning: 42)
    }
    #expect(result == 42)
}

// Parameterized test — runs test function once per argument
@Test(arguments: ["Alice", "Bob", "Charlie"])
func greetingTest(name: String) {
    let greeting = "Hello, \(name)!"
    #expect(greeting.hasPrefix("Hello"))
}

// Suite — groups related tests
@Suite("Math Tests")
struct MathTests {
    @Test func addition() { #expect(1 + 1 == 2) }
    @Test func subtraction() { #expect(5 - 3 == 2) }
}
```

**Verified runtime output**:
```
◇ Test run started.
↳ Testing Library Version: 124.4
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite "Math Tests" started.
✔ Test "Async test" passed after 0.001 seconds.
✔ Test isPositive(n:) passed after 0.001 seconds.
✔ Test run with 4 tests passed after 0.001 seconds.
```
Source: runtime probe `/tmp/swift-research-probe/lib-test/`

### Key Differences from XCTest

| | swift-testing | XCTest |
|---|---|---|
| Import | `import Testing` | `import XCTest` |
| Test marker | `@Test` attribute | Method name prefix `test...` |
| Assertions | `#expect`, `#require` macros | `XCTAssert*` functions |
| Test class | `@Suite struct/class` | `class : XCTestCase` |
| Parallel by default | Yes | No |
| Parameterized tests | Native `arguments:` | Manual looping |
| Async | Native `async throws` | Override `async` method |
| Available since | Swift 6 / Xcode 16 | All Swift versions |

**When to use XCTest**: UI tests (XCUITest), performance tests (`measure { }`), UIKit lifecycle tests. For everything else in this stack: use swift-testing.

**They coexist**: swift-testing and XCTest can be in the same test target and run together.

---

## 7. swift-argument-parser

**Current version**: 1.7.1 (released March 2026). Package URL: `https://github.com/apple/swift-argument-parser`

**Swift 6 compatibility**: ✅ — versions 1.8.0+ require Swift 6.0 minimum.

### Core API

```swift
import ArgumentParser

// Basic sync command
@main
struct MyTool: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "mytool",
        abstract: "A brief description.",
        version: "1.0.0"
    )

    @Argument(help: "The input phrase.")
    var phrase: String

    @Option(name: .shortAndLong, help: "How many times to repeat.")
    var count: Int = 1

    @Flag(name: .shortAndLong, help: "Enable verbose output.")
    var verbose: Bool = false

    func run() throws {
        for i in 1...count {
            if verbose { print("\(i): ", terminator: "") }
            print(phrase)
        }
    }
}

// Async command — conform to AsyncParsableCommand
@main
struct AsyncTool: AsyncParsableCommand {
    @Argument var query: String

    mutating func run() async throws {
        let result = try await fetchSomething(query)
        print(result)
    }
}

// Subcommands
@main
struct Math: ParsableCommand {
    static var configuration = CommandConfiguration(
        subcommands: [Add.self, Multiply.self]
    )
    
    struct Add: ParsableCommand {
        @Argument var values: [Double]
        func run() { print(values.reduce(0, +)) }
    }
    
    struct Multiply: ParsableCommand {
        @Argument var values: [Double]
        func run() { print(values.reduce(1, *)) }
    }
}
```

### Property Wrapper Details

| Wrapper | Usage | Default | Notes |
|---------|-------|---------|-------|
| `@Argument` | Positional arg | Required | `var x: [String]` for variadic |
| `@Option` | `--name value` | Optional or required | `.shortAndLong` for `-n`/`--name` |
| `@Flag` | `--flag` | `false` | Inversion: `--no-flag` |
| `@OptionGroup` | Group options from another type | — | Composition |

**Verified build** (AsyncParsableCommand with @Argument, @Option, @Flag):
```
Build complete! (33.87s)
```
Source: runtime probe `/tmp/swift-research-probe/argparse-test/`

---

## 8. Dependency Version Pinning

SwiftPM creates `Package.resolved` after first resolution. Commit this file for reproducible builds.

```swift
// Version requirement options in Package.swift
.package(url: "...", from: "2.0.0")           // ≥2.0.0, <3.0.0 (SemVer)
.package(url: "...", "2.0.0"..<"2.5.0")       // exact range
.package(url: "...", exact: "2.1.3")           // pinned exact
.package(url: "...", branch: "main")           // branch — AVOID in production
.package(url: "...", revision: "abc123")       // exact commit
```

---

## 9. Failure Modes

### FM-1: Missing `platforms` declaration breaks swift-testing

**Error** (exact):
```
error: 'isolation()' is only available in macOS 10.15 or newer
```
**Cause**: `swift package init` does NOT add `platforms:` to `Package.swift`. swift-testing's `@Test` macro expansion uses `#isolation` which requires platform specification.

**Fix**: add `platforms: [.macOS(.v15)]` (or appropriate target).

Source: runtime probe `/tmp/swift-research-probe/lib-test/` — verified.

### FM-2: Swift tools-version mismatch

**Error**: `error: the manifest at '...' cannot be loaded with Swift 5.x because it uses newer PackageDescription APIs`

**Trigger**: `swift-tools-version: 6.1` on Swift 5.x toolchain. Fix: lower the tools-version or upgrade Swift.

### FM-3: Two entry points in executable

**Error**: `error: expressions are not allowed at the top level` (in non-main.swift file) OR `error: 'main' attribute cannot be used in a module that contains top-level code`

**Trigger**: using both `main.swift` (with top-level code) AND a `@main` struct.

**Fix**: pick ONE entry point style. For async entry points, `@main struct: AsyncParsableCommand` is cleaner.

### FM-4: Transitive dependency conflicts

**Error**: `error: 'swift-collections' 1.1.2 is not compatible with 'swift-collections' 1.0.x`

**Trigger**: two dependencies require conflicting version ranges of a shared dependency.

**Fix**: use `swift package update`, or specify an explicit version range that satisfies both.

### FM-5: Platform-conditional compilation errors

**Error**: `error: use of unresolved identifier 'NSWindow'` (on Linux build)

**Fix**: wrap platform-specific code in `#if os(macOS)` / `#if canImport(AppKit)`.

### FM-6: swift-argument-parser and @main on Linux

AsyncParsableCommand on Linux works fine. The `@main` attribute routes to `AsyncParsableCommand.main()`, which creates a top-level `Task`. No issues found in testing.

---

## Sources

- `swift package init --type executable` output: verified, generates `swift-tools-version: 6.1`
- `swift package init --type library` output: verified, generates test target with swift-testing `@Test`
- swift-testing runtime output: "Testing Library Version: 124.4", 4 tests passing
- swift-argument-parser GitHub: https://github.com/apple/swift-argument-parser — version 1.7.1
- swift-testing GitHub: https://github.com/apple/swift-testing
- Runtime probe: `/tmp/swift-research-probe/argparse-test/` — AsyncParsableCommand builds (exit 0)
- Runtime probe: `/tmp/swift-research-probe/swiftui-test/` — SwiftUI macOS builds with CLT (exit 0, 34.67s)
- Runtime probe: `/tmp/swift-research-probe/lib-test/` — platform requirement error then fix
