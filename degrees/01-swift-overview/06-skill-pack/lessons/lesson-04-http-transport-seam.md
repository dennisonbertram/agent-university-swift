# Lesson 4 — HTTP Transport Seam for Testability

[Back to index](../index.md) | Prev: [Lesson 3](lesson-03-typed-clients-with-codable.md) | Next: [Lesson 5](lesson-05-anthropic-messages-api-streaming.md)

## Goal

After this lesson you can implement the `HTTPTransport` protocol, wire a production `URLSessionTransport`, and write a `MockHTTPTransport` that returns canned bytes without network calls.

## Prerequisites

[Lesson 2](lesson-02-swift6-concurrency.md) — Sendable, async/await.
[Lesson 3](lesson-03-typed-clients-with-codable.md) — Codable models.

## Concepts

### 4.1 Why a transport seam

The naive approach is to call `URLSession` directly inside the client. That makes the client impossible to test without live network. The transport seam extracts the network call into a `Sendable` protocol with two methods:

```swift
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)
}
```

`send` is for buffered requests (POST /chat). `bytes` is for streaming requests (POST /chat/stream SSE).

Evidence: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:1-12`; `patterns/http-transport-seam.md`.

### 4.2 Why `AsyncThrowingStream<UInt8, Error>` not `URLSession.AsyncBytes`

`URLSession.AsyncBytes` has no public initializer — you cannot construct one in tests:

```
error: 'URLSession.AsyncBytes' initializer is inaccessible due to 'internal' protection level
```

The production transport adapts `URLSession.AsyncBytes` into `AsyncThrowingStream<UInt8, Error>`. Tests construct streams from `Data` directly.

Evidence: `gotchas/urlsession-asyncbytes-has-no-public-init.md`; `decision-records/adr-010-asyncthrowingstream-uint8-not-urlsession-asyncbytes.md`.

### 4.3 Production `URLSessionTransport`

```swift
public struct URLSessionTransport: HTTPTransport {
    public let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }

    public func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse) {
        let (asyncBytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
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
```

Evidence: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:29-47`.

### 4.4 `MockHTTPTransport` for tests

```swift
final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    var dataResponse: (Data, HTTPURLResponse)?
    var bytesResponseData: Data?
    var bytesStatusCode: Int = 200
    var capturedRequests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequests.append(request)
        guard let r = dataResponse else { fatalError("MockHTTPTransport: no data response set") }
        return r
    }

    func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse) {
        capturedRequests.append(request)
        let data = bytesResponseData ?? Data()
        let url = request.url ?? URL(string: "http://mock")!
        let http = HTTPURLResponse(url: url, statusCode: bytesStatusCode, httpVersion: nil, headerFields: nil)!
        let stream = AsyncThrowingStream<UInt8, Error> { continuation in
            Task {
                for byte in data { continuation.yield(byte) }
                continuation.finish()
            }
        }
        return (stream, http)
    }

    func setDataResponse(json: String, statusCode: Int) {
        let data = Data(json.utf8)
        let url = URL(string: "http://mock")!
        let http = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        dataResponse = (data, http)
    }
}
```

Evidence: `L2-anthropic-client/Tests/AnthropicClientTests/MockHTTPTransport.swift:6-56`.

### 4.5 Wiring the client

```swift
public struct AnthropicClient: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let anthropicVersion: String
    public let transport: any HTTPTransport

    public init(apiKey: String,
                baseURL: URL = URL(string: "https://api.anthropic.com")!,
                anthropicVersion: String = "2023-06-01",
                transport: any HTTPTransport = URLSessionTransport()) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
        self.transport = transport
    }
}
```

In tests: `AnthropicClient(apiKey: "test", transport: mockTransport)`.
In production: `AnthropicClient(apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!)`.

Evidence: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:5-21`.

## Walkthrough — Test Without Network

```swift
@Test("Client returns decoded message on HTTP 200")
func successPath() async throws {
    let mock = MockHTTPTransport()
    mock.setDataResponse(json: """
        {"id":"msg_x","type":"message","role":"assistant","model":"claude-sonnet-4-5-20250929",
         "content":[{"type":"text","text":"Hi"}],"stop_reason":"end_turn","stop_sequence":null,
         "usage":{"input_tokens":1,"output_tokens":1}}
        """, statusCode: 200)
    let client = AnthropicClient(apiKey: "k", transport: mock)
    let req = MessageRequest(model: "claude-sonnet-4-5-20250929", maxTokens: 256,
                             messages: [InputMessage(role: .user, content: .text("hi"))])
    let resp = try await client.send(req)
    #expect(resp.content.first?.text == "Hi")
}
```

The mock captures the `URLRequest`. You can assert headers:

```swift
let captured = mock.capturedRequests[0]
#expect(captured.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
#expect(captured.value(forHTTPHeaderField: "x-api-key") == "k")
```

Evidence: `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift:28-79`.

## Pitfalls

- **Returning `URLSession.AsyncBytes` from the protocol** → tests cannot mock it. See [ts-urlsession-bytes-cannot-be-mocked.md](../troubleshooting/ts-urlsession-bytes-cannot-be-mocked.md).
- **`MockHTTPTransport` holds mutable state without `@unchecked Sendable`** → compile error. See [ts-sendable-type-cannot-be-marshalled.md](../troubleshooting/ts-sendable-type-cannot-be-marshalled.md).
- **Missing required headers** → Anthropic returns HTTP 401 or 400. See [ts-anthropic-401-unauthorized.md](../troubleshooting/ts-anthropic-401-unauthorized.md).

## Exercise

Complete [lab-03-protocol-injected-http-mock.md](../labs/lab-03-protocol-injected-http-mock.md): implement the transport seam and mock from scratch.

## Recap

- `HTTPTransport: Sendable` protocol with `send` (buffered) and `bytes` (streaming) methods.
- Return `AsyncThrowingStream<UInt8, Error>` from `bytes` — not `URLSession.AsyncBytes`.
- Production: `URLSessionTransport` adapts `URLSession.AsyncBytes` at the boundary.
- Tests: `MockHTTPTransport` constructs streams from canned `Data` with no network.
- Client is injected with `any HTTPTransport`; default is `URLSessionTransport()`.
