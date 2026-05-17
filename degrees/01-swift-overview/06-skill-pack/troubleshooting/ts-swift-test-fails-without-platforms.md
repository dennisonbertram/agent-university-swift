# Troubleshooting — `swift test` fails with `'isolation()' is only available in macOS 10.15 or newer`

[Back to index](../index.md)

## Symptom

```
error: 'isolation()' is only available in macOS 10.15 or newer
@__swiftmacro_13lib_testTests7example4TestfMp_.swift:3:65
```

The error appears in a generated macro expansion file, not in your code.

## Diagnosis

Your `Package.swift` has no `platforms:` declaration. Without it, SwiftPM defaults to the oldest deployment target the toolchain supports. The swift-testing macro `#isolation` is gated on macOS 10.15. The test target fails to build even though the library target itself is fine.

## Fix

Add `platforms:` to `Package.swift` before running anything:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MyLib",
    platforms: [.macOS(.v13)],       // ← add this
    products: [.library(name: "MyLib", targets: ["MyLib"])],
    targets: [
        .target(name: "MyLib"),
        .testTarget(name: "MyLibTests", dependencies: ["MyLib"])
    ]
)
```

Pin the minimum macOS version your code actually needs:
- Pure library, no SwiftUI: `.macOS(.v13)`
- Hummingbird 2.x backend: `.macOS(.v14)`
- SwiftUI with `@Observable`: `.macOS(.v14)`, and add `.iOS(.v17)` if multiplatform

## See also

- Distillation: `gotchas/swift-package-init-omits-platforms.md`
- Lesson: [lesson-01-swift-toolchain-and-swiftpm.md](../lessons/lesson-01-swift-toolchain-and-swiftpm.md)
