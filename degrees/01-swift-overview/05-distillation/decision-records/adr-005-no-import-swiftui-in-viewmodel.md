# ADR-005: View models do NOT `import SwiftUI`

**Date**: 2026-05-16

## Decision
Every `ChatViewModel` in the corpus (L5, L6, capstone) is in a library target and contains no `import SwiftUI`. Its imports are `AnthropicClient`, `Foundation`, `Observation`. UI-affecting state is plain Swift values (`Bool`, `String`, `enum`, `[ChatMessage]`); the views translate those values into SwiftUI.

This decision is pinned by REGRESSION-002 in L6 and the capstone: a test reads `ChatViewModel.swift` from disk and asserts no line starts with `import SwiftUI`.

## Alternatives considered
- **`import SwiftUI` in the view model** — convenient, lets you use `Color`, `Alert`, `.task` helpers from logic code.
- **A separate "view-state" struct in the view model that uses SwiftUI types** — partial isolation but still couples.

## Why no SwiftUI import in the view model
1. **Cross-platform portability.** The view model lives in `ChatCore` (the multiplatform shared library). `import SwiftUI` transitively pulls in AppKit (macOS) or UIKit (iOS), preventing the same code from compiling on Linux for backend reuse or under simpler test rigs.
2. **Logic / UI seam clarity.** The view model holds state; views render state. Mixing `Color` properties into the view model invites views to read presentation primitives instead of semantic state.
3. **Test compatibility.** Logic tests run on the test target as `@MainActor` swift-testing; they don't need any UI framework to spin up. If `import SwiftUI` were present, every test target would transitively pull SwiftUI.
4. **Architectural pin.** Once cross-platform is the goal, the absence of `import SwiftUI` is a load-bearing invariant. REGRESSION-002 makes it auditable.

## Trade-offs accepted
- **Slight friction.** Views occasionally need a one-line `Color(forStatus: vm.status)` helper because the view model exposes `enum Status` rather than `Color` directly. Worth the cost.
- **No `Alert` modelling in the view model.** Error state is `String?`, not a structured `AlertContent`. Views handle the alert presentation.

## Evidence
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:1-6` — `import AnthropicClient, Foundation, Observation`. No SwiftUI.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/ChatViewModel.swift:1-7` — explicit comment line 2: `// NO import SwiftUI — view model stays UI-framework-free for cross-platform portability`.
- POC: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/RegressionTests.swift:60-108` — REGRESSION-002.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/ChatViewModel.swift` — same.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/RegressionTests.swift:48-68` — REGRESSION-002 at the capstone level.
- Planning: `02-planning/01-shared-package-strategy.md` §6 line 233 — "If a guard is needed inside `ChatCore`, that is a signal that the abstraction is wrong and that piece should be pushed up to the shell."
- See also: pattern `patterns/mainactor-observable-viewmodel.md`, anti-pattern `anti-patterns/import-swiftui-in-viewmodel.md`.
