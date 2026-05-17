# Anti-pattern: exposing `URLSession.AsyncBytes` from a transport protocol

**Category**: anti-pattern

## Broken approach
A transport protocol whose streaming method returns the concrete `URLSession.AsyncBytes` type:

```swift
// DO NOT do this — the type cannot be constructed from canned data in tests
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(_ request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse)
}
```

## Why it fails
`URLSession.AsyncBytes` has an internal initializer. Tests cannot construct one to satisfy the protocol. Either you cannot write a mock at all, or you reach for hacks (mocking `URLSession` itself, swizzling, fake servers), all of which couple tests to Foundation internals.

```swift
// Test mock attempt — does not compile
struct MockTransport: HTTPTransport {
    var cannedBytes: Data
    func bytes(_ r: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let asyncBytes = URLSession.AsyncBytes(...)   // error: inaccessible due to 'internal' protection level
        return (asyncBytes, ...)
    }
}
```

## Right approach
Return a domain-controlled stream type — `AsyncThrowingStream<UInt8, Error>` — that both production and test code can construct. The production adapter converts `URLSession.AsyncBytes` to the stream once, at the boundary.

```swift
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse) {
        let (asyncBytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        let stream = AsyncThrowingStream<UInt8, Error> { c in
            Task {
                do { for try await b in asyncBytes { c.yield(b) }; c.finish() }
                catch { c.finish(throwing: error) }
            }
        }
        return (stream, http)
    }
}

// And in tests:
let stream = AsyncThrowingStream<UInt8, Error> { c in
    for b in cannedData { c.yield(b) }
    c.finish()
}
```

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:1-12` — comment block documents the exact rationale: "URLSession.AsyncBytes has no public initializer, making it untestable."
- POC: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:29-47` — adapter implementation.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/MockHTTPTransport.swift:22-43` — mock constructs the stream from `Data`.
- See also: gotcha `gotchas/urlsession-asyncbytes-has-no-public-init.md`, pattern `patterns/http-transport-seam.md`, ADR `decision-records/adr-010-asyncthrowingstream-uint8-not-urlsession-asyncbytes.md`.
