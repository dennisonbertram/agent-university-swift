# Swift 6 makes global mutable state a hard compile error

**Category**: gotcha

## What
Any top-level `var` in a Swift 6 target is `error: var '<X>' is not concurrency-safe because it is nonisolated global shared mutable state`. In Swift 5 the same code produced a warning. In Swift 6 it does not compile.

## Symptom
```
error: var 'globalMutableVar' is not concurrency-safe because it is
nonisolated global shared mutable state
  note: convert 'globalMutableVar' to a 'let' constant
  note: add '@MainActor' to make part of global actor 'MainActor'
  note: disable concurrency-safety checks if accesses are protected
        by an external synchronization mechanism
```

## Cause
Swift 6 turns the experimental `StrictConcurrency` checking that was opt-in in Swift 5 into the default. Anything mutable that can be touched from multiple isolation domains is rejected at compile time. `swift-tools-version: 6.1` opts every target in by default.

## Fix
Pick one of:

```swift
// 1. Immutable
let apiBaseURL = URL(string: "https://api.anthropic.com")!

// 2. Bind to MainActor
@MainActor var counter: Int = 0

// 3. Move into an actor
actor Counter { var value: Int = 0 }

// 4. Escape hatch when external locking is already in place
nonisolated(unsafe) var globalCache: [String: Any] = [:]
```

## Evidence
- Source: `degrees/01-swift-overview/01-research/01-language-and-concurrency.md` §9 "Swift 6 vs Swift 5 — The Key Difference", lines 302-325; exact error text and notes are reproduced verbatim from the probe.
- Source: `degrees/01-swift-overview/01-research/06-expectation-gaps.md` EG-01 lines 13-26, excerpt: `"error: var 'globalMutableVar' is not concurrency-safe because it is nonisolated global shared mutable state"`.
- Probe: `/tmp/swift-research-probe/global-state-test/` — exit code 1; recorded in `00-index.md` line 127.
