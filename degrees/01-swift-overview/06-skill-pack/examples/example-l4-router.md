# Example — L4: Hummingbird Router with SSE `ResponseBody`

[Back to index](../index.md) | POC: `degrees/01-swift-overview/03-pocs/L4-hummingbird-tool-service/Sources/ToolService/Router.swift`

## What this example demonstrates

- Hummingbird 2.x `buildRouter()` with middleware-first ordering.
- `GET /health`, `POST /chat` (buffered), `POST /chat/stream` (SSE).
- Plain `JSONDecoder()` for types with explicit `CodingKeys`.
- `ResponseBody { writer in ... }` for streaming.

## `buildRouter` structure

```swift
// Router.swift ~line 107
public func buildRouter(service: any LLMService) -> Router<BasicRequestContext> {
    let router = Router()

    // ─── Middleware FIRST ─────────────────────────────────────────────────────
    router.middlewares.add(LogRequestsMiddleware(.info))

    // ─── Plain decoder for types with explicit snake_case CodingKeys ──────────
    // DO NOT use .convertFromSnakeCase here — MessageRequest already has
    // explicit CodingKeys with snake_case values (e.g. max_tokens = "max_tokens").
    let requestDecoder = JSONDecoder()

    // ─── Health route ─────────────────────────────────────────────────────────
    router.get("/health") { _, _ -> Response in
        Response(status: .ok,
                 headers: [.contentType: "application/json"],
                 body: .init(byteBuffer: ByteBuffer(string: #"{"status":"ok"}"#)))
    }
```

Source: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:107-119`. Middleware is added before any routes.

## `/chat` — buffered JSON

```swift
    // Router.swift ~line 130
    router.post("/chat") { req, _ async throws -> Response in
        let collected = try await req.body.collect(upTo: 2 * 1024 * 1024)
        let data = Data(buffer: collected)

        guard let payload = try? requestDecoder.decode(MessageRequest.self, from: data) else {
            return Response(status: .badRequest,
                            headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(string: #"{"error":"invalid_request","detail":"malformed JSON"}"#)))
        }

        do {
            let message = try await service.send(payload)
            let body = try JSONEncoder().encode(message)
            return Response(status: .ok,
                            headers: [.contentType: "application/json"],
                            body: .init(byteBuffer: ByteBuffer(bytes: body)))
        } catch let e as AnthropicError {
            return mapAnthropicError(e)    // maps to 401/429/502 etc.
        }
    }
```

## `/chat/stream` — SSE

```swift
    // Router.swift ~line 175
    router.post("/chat/stream") { req, _ async throws -> Response in
        let collected = try await req.body.collect(upTo: 2 * 1024 * 1024)
        let data = Data(buffer: collected)
        let payload = try requestDecoder.decode(MessageRequest.self, from: data)
        let upstream = service.stream(payload)

        let sseBody = ResponseBody { writer in
            do {
                for try await event in upstream {
                    switch event {
                    case .contentBlockDelta(_, let text):
                        try await writer.write(ByteBuffer(string: "data: \(text)\n\n"))
                    case .messageStop:
                        try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
                        try await writer.finish(nil)
                        return
                    default: break
                    }
                }
                // Fallback: messageStop never arrived
                try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
                try await writer.finish(nil)
            } catch {
                try await writer.finish(nil)
            }
        }

        return Response(
            status: .ok,
            headers: [.contentType: "text/event-stream", .cacheControl: "no-cache"],
            body: sseBody
        )
    }
    return router
}
```

Source: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:175-203`.

## What to notice

1. `router.middlewares.add(...)` is called before any `router.get/post`. Reversing this order silently breaks middleware coverage.
2. `requestDecoder` is a plain `JSONDecoder()` — no `keyDecodingStrategy`. Adding `.convertFromSnakeCase` would break decoding of `MessageRequest`.
3. The SSE terminator `event: done\ndata: [DONE]\n\n` is emitted on both the normal `messageStop` path AND the fallback. Both paths call `writer.finish(nil)`.
4. `content-type: text/event-stream` and `cache-control: no-cache` are set on the SSE response.
