# Recipe — Bootstrap `AnthropicClient` with all required headers

[Back to index](../index.md) | See also: [lesson-05-anthropic-messages-api-streaming.md](../lessons/lesson-05-anthropic-messages-api-streaming.md) | ADR: `decision-records/adr-002-typed-anthropic-client-in-house.md`

## Use this when

You need to initialise an `AnthropicClient` and make your first call to `POST /v1/messages`.

## Required headers (hardcoded facts)

| Header | Value |
|--------|-------|
| `x-api-key` | `$ANTHROPIC_API_KEY` from environment |
| `anthropic-version` | `"2023-06-01"` (literal string) |
| `content-type` | `"application/json"` |

Missing any of these → HTTP 401 or 400.

## Client struct

```swift
import Foundation

public struct AnthropicClient: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let anthropicVersion: String
    public let transport: any HTTPTransport

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        anthropicVersion: String = "2023-06-01",
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
        self.transport = transport
    }

    private func buildURLRequest(for request: MessageRequest) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/messages")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        return urlRequest
    }
}
```

## Initialisation in production code

```swift
guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
    fputs("error: ANTHROPIC_API_KEY not set\n", stderr)
    exit(1)
}
let client = AnthropicClient(apiKey: apiKey)
```

## Initialisation in tests (no network)

```swift
let mock = MockHTTPTransport()
mock.setDataResponse(json: successJSON, statusCode: 200)
let client = AnthropicClient(apiKey: "test-key", transport: mock)
```

## Pinned model id

Use the dated variant for reproducibility:

```swift
let req = MessageRequest(
    model: "claude-sonnet-4-5-20250929",   // dated form, not "claude-sonnet-4-5"
    maxTokens: 1024,
    messages: [InputMessage(role: .user, content: .text("hi"))]
)
```

Evidence: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:5-21`; `before-you-build/anthropic-integration.md`.
