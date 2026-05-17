# Troubleshooting — `var 'X' is not concurrency-safe because it is nonisolated global shared mutable state`

[Back to index](../index.md)

## Symptom

```
error: var 'globalMutableVar' is not concurrency-safe because it is nonisolated global shared mutable state
  note: convert 'globalMutableVar' to a 'let' constant
  note: add '@MainActor' to make part of global actor 'MainActor'
  note: disable concurrency-safety checks if accesses are protected by an external synchronization mechanism
```

## Diagnosis

You have a `var` at the top level of a file in a Swift 6 target. Swift 6 makes this a hard compile error (it was a warning in Swift 5). A top-level mutable `var` is accessible from any isolation domain without synchronisation.

## Fix

Pick the first option that fits:

```swift
// Option 1: Make it immutable (no state needed)
let apiBaseURL = URL(string: "https://api.anthropic.com")!

// Option 2: Bind to @MainActor (accessed only on main thread)
@MainActor var counter: Int = 0

// Option 3: Move into an actor (serialised access)
actor AppState { var count: Int = 0 }

// Option 4: nonisolated(unsafe) — only when external locking is already in place
// Use sparingly, add a comment explaining the guarantee
nonisolated(unsafe) var globalCache: [String: Any] = [:]
```

## See also

- Distillation: `gotchas/swift6-global-mutable-state-is-error.md`
- Lesson: [lesson-02-swift6-concurrency.md](../lessons/lesson-02-swift6-concurrency.md)
