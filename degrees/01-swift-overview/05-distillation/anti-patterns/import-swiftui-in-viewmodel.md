# Anti-pattern: `import SwiftUI` in a view model

**Category**: anti-pattern

## Broken approach
Reaching for `import SwiftUI` inside a `ChatViewModel` (or any other view model) to use `Color`, `Image`, `Alert`, or a `.task` modifier helper directly from logic code.

```swift
// DO NOT DO THIS
import SwiftUI                                  // ← breaks cross-platform reuse
import Foundation

@MainActor
@Observable
public final class ChatViewModel {
    public var statusColor: Color = .gray       // ← couples logic to SwiftUI
    public func send(userText: String) async { /* ... */ }
}
```

## Why it fails
- `SwiftUI` import transitively pulls in `UIKit` (on iOS) or `AppKit` (on macOS) symbols. The view model can no longer compile on Linux for backend reuse, breaks server-side test runs, and pollutes the dep graph for iOS-only platforms.
- It blurs the architectural seam: views render state, view models hold state. Putting view-only types (`Color`, `Alert`) in the model means logic tests can't run without a UI framework.
- The capstone's REGRESSION-002 test reads the source of `ChatViewModel.swift` and fails if `import SwiftUI` appears. This is a deliberate pin; introducing the import breaks CI.

## Right approach
- Keep the view model UI-framework-free: `import Foundation`, `import AnthropicClient`, `import Observation`.
- Represent view-affecting state as plain Swift values: `enum Status { case idle, streaming, error(String) }`, not `Color`.
- Map the state to UI in the view: `Color(status:)` is a view helper, not a view-model property.

```swift
// view model — UI-framework-free
import AnthropicClient
import Foundation
import Observation

@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage] = []
    public private(set) var isStreaming: Bool = false
    public var errorMessage: String? = nil
    public var draft: String = ""
    // ... no SwiftUI types
}

// view — translates state to UI
struct StatusView: View {
    let isStreaming: Bool
    let error: String?
    var body: some View {
        if isStreaming { ProgressView() }
        else if let err = error { Text(err).foregroundColor(.red) }
    }
}
```

## Evidence
- POC: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/RegressionTests.swift:60-108` — REGRESSION-002 reads `ChatViewModel.swift` and asserts `import SwiftUI` is absent.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/RegressionTests.swift:48-68` — same pin at the capstone level.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:1-6` — imports are `AnthropicClient`, `Foundation`, `Observation` — no SwiftUI.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/ChatViewModel.swift:2-7` — same, with explicit comment line 2: `// NO import SwiftUI — view model stays UI-framework-free for cross-platform portability`.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/ChatViewModel.swift` — same, no SwiftUI.
- Planning: `02-planning/01-shared-package-strategy.md` §6 lines 219-233 — "Guards should appear in the **app shells**, not in `ChatCore`."
- See also: pattern `patterns/mainactor-observable-viewmodel.md`, ADR `decision-records/adr-005-no-import-swiftui-in-viewmodel.md`.
