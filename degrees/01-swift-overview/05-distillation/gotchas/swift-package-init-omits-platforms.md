# `swift package init` produces an incomplete Package.swift that breaks swift-testing

**Category**: gotcha

## What
`swift package init --type library` (and `--type executable`) emit a `Package.swift` with no `platforms:` declaration. The package builds, but `swift test` fails with a macro expansion error because swift-testing's `@Test` requires macOS 10.15+ for `#isolation`.

## Symptom
First run on a freshly initialised library package:
```
error: 'isolation()' is only available in macOS 10.15 or newer
@__swiftmacro_13lib_testTests7example4TestfMp_.swift:3:65
```

## Cause
Without an explicit `platforms:` entry, SwiftPM defaults to the oldest deployment target the toolchain still supports. swift-testing's macro expansion calls `#isolation` which is gated on macOS 10.15. Result: test target fails to build even though the library target itself is fine.

## Fix
Always edit the generated manifest before doing anything else:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MyLib",
    platforms: [.macOS(.v13)],   // <-- add this; pin to your minimum target
    products: [.library(name: "MyLib", targets: ["MyLib"])],
    targets: [
        .target(name: "MyLib"),
        .testTarget(name: "MyLibTests", dependencies: ["MyLib"])
    ]
)
```

Every POC in this corpus declares `platforms:` — even L1, which uses `platforms: [.macOS(.v13)]`.

## Evidence
- Source: `degrees/01-swift-overview/01-research/02-swiftpm-and-tooling.md` §9 "FM-1", lines 391-402; exact probe output.
- Source: `degrees/01-swift-overview/01-research/06-expectation-gaps.md` EG-02 lines 30-54.
- Probe: `/tmp/swift-research-probe/lib-test/` first run exit 1; second run after adding `platforms:` exit 0 (per `00-index.md` line 125).
- POC: `L1-hello-spm/Package.swift:6-8` — sets `platforms: [.macOS(.v13)]` from the start.
