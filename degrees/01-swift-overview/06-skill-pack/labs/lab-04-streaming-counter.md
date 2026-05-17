# Lab 4 — Streaming Counter

[Back to index](../index.md) | Lesson: [lesson-02-swift6-concurrency.md](../lessons/lesson-02-swift6-concurrency.md)

## Task

Implement a `Counter` that yields integers 1..N via `AsyncThrowingStream<Int, Error>` with cancellation support.

## Deliverables

- `Sources/CounterLib/Counter.swift` — the streaming counter
- `Tests/CounterLibTests/CounterTests.swift` — tests including a cancellation test
- `swift test` exits 0

## Starter `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CounterLib",
    platforms: [.macOS(.v13)],
    products: [.library(name: "CounterLib", targets: ["CounterLib"])],
    targets: [
        .target(name: "CounterLib"),
        .testTarget(name: "CounterLibTests", dependencies: ["CounterLib"]),
    ]
)
```

## Stub source

```swift
// Sources/CounterLib/Counter.swift
public struct Counter: Sendable {
    public let from: Int
    public let to: Int
    public let delayNanoseconds: UInt64

    public init(from: Int = 1, to: Int, delayNanoseconds: UInt64 = 0) {
        self.from = from
        self.to = to
        self.delayNanoseconds = delayNanoseconds
    }

    public func stream() -> AsyncThrowingStream<Int, Error> {
        // TODO: yield integers from `from` to `to`, check cancellation, set onTermination
        fatalError("not implemented")
    }
}
```

## Requirements

1. `stream()` returns an `AsyncThrowingStream<Int, Error>`.
2. It yields integers `from` through `to` (inclusive) in order.
3. Between each yield, if `delayNanoseconds > 0`, it calls `try await Task.sleep(nanoseconds: delayNanoseconds)`.
4. It calls `try Task.checkCancellation()` in the loop.
5. `continuation.onTermination = { _ in task.cancel() }` is set so consumer cancellation propagates.
6. After yielding all values, it calls `continuation.finish()`.

## Required tests

1. Yields exactly the integers 1..10 in order.
2. Cancelling the consumer mid-stream stops the producer (the in-flight task is cancelled).
3. Starting from a custom `from` value works correctly.

## Cancellation test pattern

```swift
@Test("Consumer cancels mid-stream — producer stops")
func cancellationStopsProducer() async throws {
    let counter = Counter(to: 100, delayNanoseconds: 1_000_000)   // 1ms delay
    var received: [Int] = []
    let stream = counter.stream()
    let task = Task {
        for try await n in stream {
            received.append(n)
            if n == 3 { break }    // stop after 3 values
        }
    }
    await task.value
    // Should have stopped at 3, not gone all the way to 100
    #expect(received.count <= 5)   // allow a little slack for timing
    #expect(received.first == 1)
    #expect(received.contains(3))
    #expect(!received.contains(50))
}
```

## Verification

```bash
swift test
```

<details>
<summary>Hint</summary>

```swift
public func stream() -> AsyncThrowingStream<Int, Error> {
    let from = self.from
    let to = self.to
    let delay = self.delayNanoseconds

    return AsyncThrowingStream { continuation in
        let task = Task {
            do {
                for i in from...to {
                    try Task.checkCancellation()
                    continuation.yield(i)
                    if delay > 0 { try await Task.sleep(nanoseconds: delay) }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

</details>
