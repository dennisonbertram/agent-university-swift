# Troubleshooting — Background Task Keeps Running After View Disappears

[Back to index](../index.md)

## Symptom

A view is dismissed or navigated away from, but an LLM streaming task continues running in the background. Memory and CPU stay elevated. Subsequent requests use stale state or conflict with the orphaned task.

## Diagnosis

The `AsyncThrowingStream` producer task has no `onTermination` handler. When the consumer's `for try await` loop exits (because the view disappeared and the `.task` modifier was cancelled), the continuation terminates but the producer `Task` is not cancelled. The `URLSession` request keeps running.

## Fix

Always set `continuation.onTermination`:

```swift
return AsyncThrowingStream { continuation in
    let task = Task {
        // ... producer work ...
    }
    continuation.onTermination = { _ in task.cancel() }    // ← critical
}
```

In a `@MainActor` view model, the stream task is stored and cancelled on `cancel()`:

```swift
public func cancel() {
    streamTask?.cancel()
    streamTask = nil
    isStreaming = false
}
```

In a SwiftUI view, use the `.task` modifier (which automatically cancels when the view disappears) instead of `Task { ... }` in `onAppear`:

```swift
// Preferred: .task cancels automatically
.task {
    for try await chunk in session.send(userText: text) {
        // ...
    }
}

// Avoid: Task in onAppear won't cancel when view disappears
.onAppear {
    Task { for try await chunk in session.send(userText: text) { /* ... */ } }
}
```

## See also

- Distillation: `patterns/asyncthrowingstream-with-onTermination.md`
- Lesson: [lesson-02-swift6-concurrency.md](../lessons/lesson-02-swift6-concurrency.md)
