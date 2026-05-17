# Playbook: debug Swift 6 strict-concurrency / Sendable compile errors

**Goal**: Recognize the half-dozen Swift 6 concurrency error templates and apply the canonical fix without trial-and-error.

## Prerequisites
- A Swift 6.1+ toolchain.
- A `Package.swift` with `swift-tools-version: 6.1` (Swift 6 language mode on by default).

## The five errors and their fixes

### 1. Global mutable state

```
error: var 'X' is not concurrency-safe because it is nonisolated global shared mutable state
  note: convert 'X' to a 'let' constant
  note: add '@MainActor' to make part of global actor 'MainActor'
```

Fix order, pick the first that fits:
1. `let` if it really doesn't change.
2. `@MainActor var X: T = ...` if access is always on the main thread.
3. Move into an actor.
4. `nonisolated(unsafe) var X: T = ...` if external locking is in place. Last resort.

### 2. Capture of mutable var in concurrent closure

```
error: mutation of captured var 'X' in concurrently-executing code
```

Fix: pre-snapshot to a local `let` before the closure (see gotcha `gotchas/captured-let-snapshot-in-sendable-closure.md`):
```swift
var streamRequest = request
streamRequest.stream = true
let frozenRequest = streamRequest        // <-- snapshot
AsyncThrowingStream { continuation in
    Task { let r = try self.buildURLRequest(for: frozenRequest); /* ... */ }
}
```

### 3. Non-Sendable class crossing isolation

```
error: stored property '<X>' of 'Sendable'-conforming class '<MockType>' is mutable
```

Fix: declare `final class … @unchecked Sendable` plus an `NSLock` if cross-isolation access is real:
```swift
final class MockUpstreamLLMService: LLMService, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [StreamEvent] = []
    var events: [StreamEvent] {
        get { lock.withLock { _events } }
        set { lock.withLock { _events = newValue } }
    }
}
```

### 4. Existential `any` keyword missing

```
error: use of protocol 'X' as a type must be written 'any X'
```

Fix: just add `any`:
```swift
public let service: any LLMService     // not "LLMService"
```

### 5. Platform availability inside `@Test`

```
error: 'isolation()' is only available in macOS 10.15 or newer
```

Fix: add `platforms:` to Package.swift (see gotcha `gotchas/swift-package-init-omits-platforms.md`):
```swift
platforms: [.macOS(.v13)],
```

### 6. await inside non-async context

```
error: 'async' call in a function that does not support concurrency
```

Fix: mark the enclosing function `async`, or wrap the call in `Task { ... }`.

## A diagnostic flow

1. Read the error template. Match against the five above.
2. Match the fix. Apply it.
3. **Don't pre-emptively `@unchecked Sendable`-mark every class**. Region-based isolation (SE-0414) often makes the cross legal without an annotation; let the compiler tell you when it actually needs help (see research §EG-10).
4. If you find yourself adding `nonisolated(unsafe)` or `@unchecked Sendable` more than once or twice, re-think the architecture — the corpus uses both only in tests and a single client struct.

## You'll know it worked when…
- `swift build` exits 0 with the targeted Swift 6.1 toolchain.
- The fix is the one you'd write again next time without thinking.

## Evidence
- Research: `01-research/01-language-and-concurrency.md` §9, §11, §12 lines 272-460 — full Swift 6 concurrency reference.
- Research: `01-research/06-expectation-gaps.md` EG-01 (warnings→errors) and EG-10 (region-based isolation permissiveness).
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:51-55` — let-snapshot pattern.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/MockHTTPTransport.swift:6` — `@unchecked Sendable` mock.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/MockUpstreamLLMService.swift:9-31` — NSLock + `@unchecked Sendable` for real cross-isolation access.
- POC: every `Package.swift` in the corpus declares `platforms:` explicitly.
- See also: gotcha `gotchas/swift6-global-mutable-state-is-error.md`, `gotchas/captured-let-snapshot-in-sendable-closure.md`, `gotchas/unchecked-sendable-needed-for-test-mocks.md`, `gotchas/swift-package-init-omits-platforms.md`.
