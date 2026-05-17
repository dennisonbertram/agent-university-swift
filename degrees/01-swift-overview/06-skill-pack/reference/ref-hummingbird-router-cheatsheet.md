# Reference — Hummingbird 2.x Router Cheat Sheet

[Back to index](../index.md)

## Application setup

```swift
import Hummingbird

let router = Router()
// ... add middleware and routes ...
let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080),
                         serverName: "my-server")
)
try await app.runService()   // handles SIGTERM/SIGINT gracefully
```

## Route registration

```swift
router.get("/path") { _, _ -> String in "response" }
router.post("/path") { req, ctx async throws -> Response in /* ... */ }
router.put("/path") { req, ctx in /* ... */ }
router.delete("/path") { req, ctx in /* ... */ }
```

Handler returns anything that conforms to `ResponseGenerator`: `String`, `HTTPResponse.Status`, `Response`, or a `Codable & ResponseCodable` type.

## Middleware — register BEFORE routes

```swift
router.middlewares.add(LogRequestsMiddleware(.info))   // FIRST
router.get("/health") { _, _ in /* ... */ }            // AFTER
router.post("/chat") { req, _ in /* ... */ }           // AFTER
```

Middleware is positional — routes registered before `middlewares.add(...)` are not covered.

## Request body collection

```swift
router.post("/data") { req, _ async throws -> Response in
    let collected = try await req.body.collect(upTo: 2 * 1024 * 1024)
    let data = Data(buffer: collected)
    let payload = try JSONDecoder().decode(MyType.self, from: data)
    // ...
}
```

## JSON response

```swift
let responseData = try JSONEncoder().encode(myValue)
return Response(
    status: .ok,
    headers: [.contentType: "application/json"],
    body: .init(byteBuffer: ByteBuffer(bytes: responseData))
)
```

## SSE (streaming) response

```swift
let sseBody = ResponseBody { writer in
    for try await chunk in myStream {
        try await writer.write(ByteBuffer(string: "data: \(chunk)\n\n"))
    }
    try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
    try await writer.finish(nil)
}
return Response(
    status: .ok,
    headers: [.contentType: "text/event-stream", .cacheControl: "no-cache"],
    body: sseBody
)
```

## Error response

```swift
return Response(
    status: .badRequest,
    headers: [.contentType: "application/json"],
    body: .init(byteBuffer: ByteBuffer(string: #"{"error":"bad_request","detail":"..."}"#))
)
```

## In-process testing

```swift
import HummingbirdTesting

try await app.test(.router) { client in           // no socket, synchronous
    try await client.execute(uri: "/health", method: .get) { response in
        #expect(response.status == .ok)
    }
}

try await app.test(.live) { client in             // NIO test transport, async
    let body = ByteBuffer(string: requestJSON)
    try await client.execute(uri: "/chat", method: .post,
                             headers: [.contentType: "application/json"],
                             body: body) { response in
        #expect(response.status == .ok)
    }
}
```

**Neither `.router` nor `.live` can be dialled by `URLSession`.** Use `withLiveBackendForURLSession` for that — see [lesson-10-end-to-end-integration-testing.md](../lessons/lesson-10-end-to-end-integration-testing.md).

Evidence: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift`; `01-research/04-hummingbird.md`.
