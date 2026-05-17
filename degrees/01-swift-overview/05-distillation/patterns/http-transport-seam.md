# Pattern: HTTPTransport protocol seam for testable HTTP clients

**Category**: pattern

## What
Define a small `Sendable` protocol that abstracts the network surface your client needs — typically two methods: a buffered `send(_:) -> (Data, HTTPURLResponse)` and a streaming `bytes(_:) -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)`. The client depends on the protocol; production wires `URLSessionTransport`; tests wire a mock that returns canned bytes. No live network in unit tests.

## When to apply
- You are building a typed Swift client over `URLSession` and want test coverage without flakey network calls.
- Your client needs both buffered (`POST /chat`) and streaming (`POST /chat?stream=true` SSE) endpoints — most LLM APIs.
- You want to keep the entire client `Sendable` so it crosses actor boundaries cleanly.

## Canonical code

```swift
import Foundation

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

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
}

public struct AnthropicClient: Sendable {
    public let transport: any HTTPTransport
    public init(apiKey: String, transport: any HTTPTransport = URLSessionTransport()) { /* ... */ }
}
```

In tests:
```swift
final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    var dataResponse: (Data, HTTPURLResponse)?
    var bytesResponseData: Data?
    var bytesStatusCode: Int = 200
    var capturedRequests: [URLRequest] = []
    // ...
}
```

## Variants and trade-offs
- Use `AsyncThrowingStream<UInt8, Error>` not `URLSession.AsyncBytes` — the latter has no public init and breaks mocks (see `gotchas/urlsession-asyncbytes-has-no-public-init.md`).
- Production `URLSessionTransport` is a `struct` (cheap value copy) and the protocol itself is `Sendable`, so the whole client composes cleanly across actor boundaries.
- For very simple clients you can collapse `send`/`bytes` into one method, but the corpus consistently uses two.

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:9-48` — full protocol and adapter.
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:5-21` — client constructor accepts `any HTTPTransport`.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/MockHTTPTransport.swift` — full mock with `setDataResponse(json:statusCode:)` helper.
- See also: gotcha `gotchas/urlsession-asyncbytes-has-no-public-init.md`, ADR `decision-records/adr-010-asyncthrowingstream-uint8-not-urlsession-asyncbytes.md`, playbook `playbooks/playbook-call-anthropic-from-swift.md`.
