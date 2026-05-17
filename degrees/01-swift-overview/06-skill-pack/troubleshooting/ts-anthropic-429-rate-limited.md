# Troubleshooting — HTTP 429 Rate Limited

[Back to index](../index.md)

## Symptom

```json
{"type":"error","error":{"type":"rate_limit_error","message":"Number of request tokens has exceeded your per-minute rate limit..."}}
```

HTTP 429 from Anthropic.

## Diagnosis

You have exceeded the rate limit for your API key tier. Anthropic returns a `Retry-After` header indicating how many seconds to wait.

Note: Anthropic also uses HTTP 529 for overloaded (non-standard). Treat it like 429 with backoff.

## Fix in the client

Map 429 to a typed error that captures `Retry-After`:

```swift
case 429:
    let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
    throw AnthropicError.rateLimited(retryAfter: retryAfter, body: body)
```

Surface `Retry-After` to the caller so they can implement backoff:

```swift
catch let e as AnthropicError {
    if case .rateLimited(let retryAfter, _) = e {
        let seconds = retryAfter.flatMap(Double.init) ?? 60
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        // retry
    }
}
```

## In a Hummingbird proxy

Forward the `Retry-After` header to the caller:

```swift
case .rateLimited(let retryAfter, let body):
    var headers: HTTPFields = [.contentType: "application/json"]
    if let ra = retryAfter { headers[.init("retry-after")!] = ra }
    return Response(status: .tooManyRequests,
                    headers: headers,
                    body: .init(byteBuffer: ByteBuffer(string: errorJSON(body))))
```

Evidence: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift`; `patterns/typed-error-enum-with-bodies.md`.

## See also

- Lesson: [lesson-05-anthropic-messages-api-streaming.md](../lessons/lesson-05-anthropic-messages-api-streaming.md)
- Before-you-build: `before-you-build/anthropic-integration.md`
