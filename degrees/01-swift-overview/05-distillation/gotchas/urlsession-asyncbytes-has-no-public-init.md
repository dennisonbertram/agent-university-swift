# `URLSession.AsyncBytes` cannot be constructed in tests — it has no public initializer

**Category**: gotcha

## What
If your HTTP transport protocol returns `URLSession.AsyncBytes` directly, you cannot write a mock that returns one. `URLSession.AsyncBytes` is `internal init` only; tests that need to feed canned bytes into your client will not compile.

## Symptom
```
error: 'URLSession.AsyncBytes' initializer is inaccessible due to 'internal' protection level
```
…or, if you avoid the init, the entire seam becomes untestable and you reach for live network calls in unit tests.

## Cause
Foundation declares `URLSession.AsyncBytes` with an internal initializer. Only `URLSession.bytes(for:)` returns one. You cannot wrap canned `Data` in an `AsyncBytes`.

## Fix
Make the transport protocol return `AsyncThrowingStream<UInt8, Error>` instead of `URLSession.AsyncBytes`. The production `URLSessionTransport` adapts the real `AsyncBytes` into a stream; mocks construct streams directly from `Data`.

```swift
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

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
    // send(_:) unchanged
}
```

Mocks can now do:

```swift
let stream = AsyncThrowingStream<UInt8, Error> { c in
    for byte in cannedData { c.yield(byte) }
    c.finish()
}
```

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:1-12` — the leading comment documents this exact decision: `"URLSession.AsyncBytes has no public initializer, making it untestable."`
- POC: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:29-47` — adapter implementation.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/MockHTTPTransport.swift:22-43` — mock constructs the stream from `Data`.
- See also: pattern `patterns/http-transport-seam.md`, ADR `decision-records/adr-010-asyncthrowingstream-uint8-not-urlsession-asyncbytes.md`.
