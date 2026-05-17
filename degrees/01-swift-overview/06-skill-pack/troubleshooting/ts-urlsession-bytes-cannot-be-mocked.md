# Troubleshooting — `URLSession.AsyncBytes` initializer is inaccessible

[Back to index](../index.md)

## Symptom

```
error: 'URLSession.AsyncBytes' initializer is inaccessible due to 'internal' protection level
```

This appears in test code trying to construct a `URLSession.AsyncBytes` to feed into a mock.

## Diagnosis

`URLSession.AsyncBytes` has an internal initializer. Only `URLSession.bytes(for:)` can return one. You cannot construct `URLSession.AsyncBytes` from test data. If your transport protocol returns `URLSession.AsyncBytes`, the seam is fundamentally untestable.

## Fix

Make the transport protocol return `AsyncThrowingStream<UInt8, Error>` instead:

```swift
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)
}
```

The production `URLSessionTransport` adapts `URLSession.AsyncBytes` at the boundary:

```swift
public func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse) {
    let (asyncBytes, response) = try await session.bytes(for: request)
    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
    let stream = AsyncThrowingStream<UInt8, Error> { continuation in
        Task {
            do {
                for try await byte in asyncBytes { continuation.yield(byte) }
                continuation.finish()
            } catch { continuation.finish(throwing: error) }
        }
    }
    return (stream, http)
}
```

Tests construct streams from `Data`:

```swift
func makeByteStream(from data: Data) -> AsyncThrowingStream<UInt8, Error> {
    AsyncThrowingStream { continuation in
        Task {
            for byte in data { continuation.yield(byte) }
            continuation.finish()
        }
    }
}
```

## See also

- Distillation: `gotchas/urlsession-asyncbytes-has-no-public-init.md`
- ADR: `decision-records/adr-010-asyncthrowingstream-uint8-not-urlsession-asyncbytes.md`
- Anti-pattern: `anti-patterns/urlsession-asyncbytes-in-public-protocol.md`
- Lesson: [lesson-04-http-transport-seam.md](../lessons/lesson-04-http-transport-seam.md)
