# Troubleshooting — Multiplatform Package Fails with iOS-Only or macOS-Only API

[Back to index](../index.md)

## Symptom

```
error: cannot find 'UIView' in scope
error: cannot find type 'NSView' in scope
error: 'import AppKit' is not available on this platform
```

or the build succeeds on macOS but fails when the Xcode iOS project builds the same shared target.

## Diagnosis

A shared library target imports a platform-specific framework:
- `import AppKit` — macOS only
- `import UIKit` — iOS only
- `import Combine` — not forbidden, but avoid; use `Observation` instead

The shared target must compile on both platforms. Platform-specific types are not available on the other platform.

## Fix

**Remove the forbidden import from shared targets.** The allowed imports in a cross-platform shared library:

```swift
import Foundation
import Observation
import SwiftUI        // allowed in view files, not in view models
// Your LLM client library
```

If you need platform-specific behaviour, push it to the platform-specific app shell (executable target), not the shared library.

For the small set of platform-specific view modifiers, use `#if os()` guards:

```swift
.navigationTitle("Claude")
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
```

**Never put `#if os()` guards in the view model.** If you find yourself needing to, the abstraction is wrong.

## Detecting the problem early

`swift build` on macOS does not catch `import UIKit` in shared code — it only fails when Xcode builds for iOS. To catch it early:

- Add `.iOS(.v17)` to `platforms:` in the shared package.
- Open the package in Xcode and verify the iOS simulator scheme builds.

## See also

- Distillation: `anti-patterns/import-swiftui-in-viewmodel.md`
- Lesson: [lesson-09-multiplatform-swift-packages.md](../lessons/lesson-09-multiplatform-swift-packages.md)
- Pattern: `patterns/cross-platform-swiftui-guards.md`
- Before-you-build: `before-you-build/swiftui-multiplatform.md`
