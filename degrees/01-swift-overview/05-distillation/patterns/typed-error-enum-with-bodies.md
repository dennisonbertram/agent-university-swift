# Pattern: typed `Error` enum with body payloads for HTTP error mapping

**Category**: pattern

## What
Model API failures as a `Codable & Equatable & Sendable` enum where each case carries the response body and any relevant header (e.g. `Retry-After`). The client maps HTTP status codes to enum cases. Downstream layers (HTTP services, view models) switch on the enum to produce user-facing messages and re-emit the right HTTP status.

## When to apply
- Any typed client over a JSON HTTP API where you want callers to handle failure modes specifically (401 vs 429 vs 5xx).
- Any time you want errors to round-trip through a backend proxy without losing fidelity.

## Canonical code

The error enum:

```swift
public enum AnthropicError: Error, Equatable, Sendable {
    case unauthorized(body: String)
    case rateLimited(retryAfter: String?, body: String)
    case badRequest(body: String)
    case serverError(status: Int, body: String)
    case decodeFailure(underlying: String)
    case streamProtocol(message: String)
}
```

The client maps statuses:

```swift
switch response.statusCode {
case 200:  return try JSONDecoder().decode(Message.self, from: data)
case 400:  throw AnthropicError.badRequest(body: body)
case 401:  throw AnthropicError.unauthorized(body: body)
case 429:
    let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
    throw AnthropicError.rateLimited(retryAfter: retryAfter, body: body)
default:   throw AnthropicError.serverError(status: response.statusCode, body: body)
}
```

The backend re-emits with matching HTTP semantics:

```swift
func mapAnthropicError(_ e: AnthropicError) -> Response {
    switch e {
    case .unauthorized(let body):
        return errorResponse(status: .unauthorized, error: "unauthorized", detail: body)
    case .rateLimited(let retryAfter, let body):
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        if let ra = retryAfter, let name = HTTPField.Name("Retry-After") {
            headers[name] = ra
        }
        return Response(status: .tooManyRequests, headers: headers,
                        body: .init(byteBuffer: ByteBuffer(bytes: try! JSONEncoder.snake.encode(ErrorBody(error: "rate_limited", detail: body)))))
    case .badRequest(let body):
        return errorResponse(status: .badRequest, error: "bad_request", detail: body)
    case .serverError(_, let body):
        return errorResponse(status: .badGateway, error: "upstream_error", detail: body)
    // ...
    }
}
```

The view model surfaces the error:

```swift
private func humanReadable(_ error: Error) -> String {
    if let e = error as? AnthropicError {
        switch e {
        case .unauthorized: return "Unauthorized — check ANTHROPIC_API_KEY."
        case .rateLimited(let retryAfter, _):
            return retryAfter.map { "Rate limited — retry after \($0)s." } ?? "Rate limited."
        case .badRequest(let body): return "Bad request: \(body)"
        case .serverError(let s, _): return "Server error \(s)."
        case .decodeFailure(let u): return "Decode error: \(u)"
        case .streamProtocol(let m): return "Stream error: \(m)"
        }
    }
    return "Unexpected error: \(error)"
}
```

## Variants and trade-offs
- The enum is `Equatable` so tests can `#expect(error == AnthropicError.unauthorized(body: ""))` (with care around the body string).
- Each case carries the raw response body — never throw away upstream context. Downstream maps may strip it for the user but logs see it.
- `Retry-After` is special-cased: the upstream client puts it on the error, the backend forwards it back as an HTTP header. This is one of the few places where header-level information escapes the body.
- The backend deliberately downgrades upstream `serverError(status:)` to HTTP 502 Bad Gateway in the proxy response, signalling "the proxy is fine, the upstream is not."

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/Errors.swift:3-10` — full enum.
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:30-46` — status mapping.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:54-87` — `mapAnthropicError(_:)` with `Retry-After` forwarding.
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/ErrorMappingTests.swift:14-119` — four tests covering 401, 429+Retry-After, 400, 502.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:121-134` — UI mapping.
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/Router.swift:53-86` — repeats the pattern.
- Research: `01-research/03-anthropic-api-in-swift.md` §10 lines 559-614 — failure modes.
