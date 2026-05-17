# Playbook: take a macOS SwiftPM package multiplatform (iOS + macOS) without breaking macOS-only consumers

**Goal**: Make a library declared as `platforms: [.macOS(.v14)]` consumable from both an Xcode iOS app and `swift build` on macOS, while keeping all existing tests green.

## Prerequisites
- A working macOS-only SwiftPM package with `@MainActor @Observable` view model (see `playbooks/playbook-swiftui-chat-ui.md`).
- A target iOS deployment version — the corpus uses `.iOS(.v17)` (required for `@Observable`).

## Steps

1. Extend `platforms:`:
   ```swift
   platforms: [
       .iOS(.v17),
       .macOS(.v14)
   ],
   ```

2. **Audit `import` statements** in shared targets. Forbidden in cross-platform code:
   - `import AppKit` (macOS-only)
   - `import UIKit` (iOS-only)
   - `import Combine` (avoid; use `Observation`)
   - Avoid `import SwiftUI` in view models (see anti-pattern `anti-patterns/import-swiftui-in-viewmodel.md`)

   The library should import only: `Foundation`, `AnthropicClient`, `Observation`, and `SwiftUI` (in view files only).

3. Identify the small set of view modifiers that need platform guards (see pattern `patterns/cross-platform-swiftui-guards.md`). The recurring ones in this corpus:
   - `.navigationBarTitleDisplayMode(.inline)` — `#if os(iOS)`
   - `.submitLabel(.send)` — `#if os(iOS)`
   - `.windowResizability(.contentSize)` — `#if os(macOS)` (lives in the app shell, not the library)

   ```swift
   public struct ChatScreen: View {
       @Bindable public var vm: ChatViewModel
       public var body: some View {
           VStack(spacing: 0) { /* ... */ }
               .navigationTitle("Claude")
               #if os(iOS)
               .navigationBarTitleDisplayMode(.inline)
               #endif
       }
   }
   ```

4. Run macOS tests to verify nothing broke:
   ```bash
   swift build
   swift test
   ```
   Tests in this corpus run on macOS but the code under test compiles cross-platform — sufficient for logic.

5. Add a REGRESSION pin against the architectural invariant. The L6/capstone pin reads the view model source and asserts `import SwiftUI` is absent:

   ```swift
   @Test("REGRESSION-002: ChatViewModel.swift contains no 'import SwiftUI'")
   func chatViewModelHasNoSwiftUIImport() throws {
       let packageRoot = URL(fileURLWithPath: #filePath)
           .deletingLastPathComponent()      // tests dir
           .deletingLastPathComponent()      // Tests dir
           .deletingLastPathComponent()      // package root
       let vmPath = packageRoot.appendingPathComponent("Sources/ChatCoreShared/ChatViewModel.swift")
       let source = try String(contentsOf: vmPath, encoding: .utf8)
       let hasImport = source.components(separatedBy: "\n").contains {
           $0.trimmingCharacters(in: .whitespaces).hasPrefix("import SwiftUI")
       }
       #expect(!hasImport)
   }
   ```

6. Set up the iOS app shell as bare `.swift` files in `iosApp/` plus an `OPEN-IN-XCODE.md` walkthrough. Do NOT generate a `.xcodeproj` (see anti-pattern `anti-patterns/hand-written-xcodeproj-pbxproj.md`).

7. Verify iOS integration manually: open Xcode, create a new iOS App, add the SwiftPM package as a local dependency, drop in `iosApp/*.swift`, build for simulator.

## You'll know it worked when…
- `swift build` and `swift test` still succeed on macOS.
- `swift build` (with `-Xswiftc -target-cpu` arm64 etc. — implicit) does not fail on `import` statements.
- The Xcode iOS App project, with the local SwiftPM dep added, builds the simulator target without errors.
- The REGRESSION-002 test fails immediately if anyone adds `import SwiftUI` to the view model.

## Evidence
- POC: `L6-swiftui-ios-app/Package.swift:1-28` — multiplatform manifest.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/ChatViewModel.swift:1-7` — explicit comment "NO import SwiftUI".
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/Views/ChatScreen.swift:27-29` — `#if os(iOS)` guard.
- POC: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/RegressionTests.swift:60-108` — REGRESSION-002 pin.
- POC: `L6-swiftui-ios-app/iosApp/ChatIOSApp.swift`, `RootView.swift`, `OPEN-IN-XCODE.md` — iOS shell strategy.
- POC: `L-capstone-multiplatform-chat/Package.swift:1-64` — final multiplatform package with 3 products.
- Planning: `02-planning/01-shared-package-strategy.md` — full strategy doc.
- See also: pattern `patterns/multiplatform-spm-package.md`, pattern `patterns/cross-platform-swiftui-guards.md`.
