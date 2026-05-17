# Lesson 7 — Hummingbird HTTP Services

[Back to index](../index.md) | Prev: [Lesson 6](lesson-06-cli-tools-with-argument-parser.md) | Next: [Lesson 8](lesson-08-swiftui-macos-app.md)

## Goal

After this lesson you can build a Hummingbird 2.x HTTP service with routing, middleware, JSON handlers, SSE streaming responses, and in-process tests.

## Prerequisites

[Lesson 4](lesson-04-http-transport-seam.md) — HTTP transport concepts.
[Lesson 5](lesson-05-anthropic-messages-api-streaming.md) — SSE streaming.

## Concepts

### 7.1 Hummingbird 1.x vs 2.x

Hummingbird 2.x (2024+) is a ground-up redesign for Swift structured concurrency. There is no `HBApplication`, `HBRequest`, `HBMiddleware`, or `EventLoopFuture` in 2.x. Every LLM-generated Hummingbird snippet from before 2024 is wrong.

```
error: cannot find 'HBApplication' in scope
error: cannot find type 'HBRequest' in scope
error: cannot find type 'HBMiddleware' in scope
```

See [ts-hummingbird-1x-types-in-2x-project.md](../troubleshooting/ts-hummingbird-1x-types-in-2x-project.md) for the quick migration table.

Evidence: `gotchas/hummingbird-1x-syntax-does-not-compile-on-2x.md`; `01-research/04-hummingbird.md §10`.

### 7.2 Package.swift setup

```swift
dependencies: [
    .package(path: "../L2-anthropic-client"),
    .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0")
],
targets: [
    .target(name: "ToolService",
            dependencies: [
                .product(name: "AnthropicClient", package: "L2-anthropic-client"),
                .product(name: "Hummingbird", package: "hummingbird")
            ]),
    .executableTarget(name: "tool-server", dependencies: ["ToolService"]),
    .testTarget(name: "ToolServiceTests",
                dependencies: ["ToolService",
                               .product(name: "Hummingbird", package: "hummingbird"),
                               .product(name: "HummingbirdTesting", package: "hummingbird")])
]
```

Evidence: `L4-hummingbird-tool-service/Package.swift`.

### 7.3 Minimal application

```swift
import Hummingbird

let router = Router()
router.get("hello") { _, _ -> String in "Hello, Hummingbird!" }

let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
try await app.runService()
```

`runService()` handles `SIGTERM`/`SIGINT` graceful shutdown via `ServiceLifecycle`.

Evidence: `gotchas/hummingbird-1x-syntax-does-not-compile-on-2x.md`; `L4-hummingbird-tool-service/Sources/tool-server/main.swift`.

### 7.4 Middleware ordering — critical

**Middleware applies only to routes registered AFTER `middlewares.add(_:)`.** It is positional, not global.

```swift
public func buildRouter(service: any LLMService) -> Router<BasicRequestContext> {
    let router = Router()
    router.middlewares.add(LogRequestsMiddleware(.info))   // FIRST

    // Routes registered AFTER the middleware call will be logged:
    router.get("/health") { _, _ in /* ... */ }
    router.post("/chat") { req, _ in /* ... */ }
    router.post("/chat/stream") { req, _ in /* ... */ }
    return router
}
```

If a route is registered before `middlewares.add(...)`, it does not see that middleware. See [ts-hummingbird-middleware-not-applied.md](../troubleshooting/ts-hummingbird-middleware-not-applied.md).

Evidence: `gotchas/hummingbird-middleware-only-applies-to-routes-added-after.md`; `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:107-119`.

### 7.5 JSON request decoding

Hummingbird does not auto-decode request bodies. Collect the body manually, then decode:

```swift
router.post("/chat") { req, _ async throws -> Response in
    let collected = try await req.body.collect(upTo: 2 * 1024 * 1024)
    let data = Data(buffer: collected)
    let requestDecoder = JSONDecoder()   // plain — no .convertFromSnakeCase
    let payload = try requestDecoder.decode(MessageRequest.self, from: data)
    // ...
}
```

Use a **plain** `JSONDecoder()` for types with explicit snake_case `CodingKeys`. Evidence: `gotchas/snake-case-codable-double-transform.md`.

### 7.6 SSE streaming response body

```swift
router.post("/chat/stream") { req, _ async throws -> Response in
    let data = try await collectBodyData(req)
    let payload = try requestDecoder.decode(MessageRequest.self, from: data)
    let upstream = service.stream(payload)

    let sseBody = ResponseBody { writer in
        do {
            for try await event in upstream {
                switch event {
                case .contentBlockDelta(_, let text):
                    let frame = "data: \(text)\n\n"
                    try await writer.write(ByteBuffer(string: frame))
                case .messageStop:
                    try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
                    try await writer.finish(nil)
                    return
                default: break
                }
            }
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
```

Always emit the terminator on both the happy path AND the error/fallback path. Otherwise SSE clients hang.

Evidence: `patterns/hummingbird-streaming-response-body.md`; `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:175-203`.

### 7.7 In-process testing with `HummingbirdTesting`

```swift
import HummingbirdTesting

@Test func healthReturnsOK() async throws {
    let mock = MockLLMService()
    let router = buildRouter(service: mock)
    let app = Application(router: router)
    try await app.test(.router) { client in
        try await client.execute(uri: "/health", method: .get) { response in
            #expect(response.status == .ok)
        }
    }
}
```

`app.test(.router)` — no socket, synchronous call through the responder. Fast.
`app.test(.live)` — starts a real server on a free port using NIO's test transport. Use when you need realistic async behaviour (e.g. streaming).

**Important:** Neither transport can be dialled by `URLSession`. For end-to-end tests that exercise `URLSession`, use the `withLiveBackendForURLSession` helper. See [lesson-10-end-to-end-integration-testing.md](lesson-10-end-to-end-integration-testing.md) and [ts-hummingbird-route-returns-404.md](../troubleshooting/ts-hummingbird-route-returns-404.md).

Evidence: `gotchas/hummingbird-test-live-vs-router-transport.md`.

## Walkthrough — Full Router Build

See the annotated example: [example-l4-router.md](../examples/example-l4-router.md).

Structure of `L4-hummingbird-tool-service`:
```
Sources/
  ToolService/
    Router.swift          # buildRouter(service:) — all three routes
    LLMService.swift      # local protocol seam
    ErrorBody.swift       # uniform {"error":...,"detail":...} body
  tool-server/
    main.swift            # Application init, runService()
Tests/
  ToolServiceTests/
    HealthTests.swift
    ChatEndpointTests.swift
    ChatStreamEndpointTests.swift
    ErrorMappingTests.swift
    RegressionTests.swift
```

## Pitfalls

- **Using Hummingbird 1.x API** (`HBApplication`, `HBMiddleware`, etc.) → compile errors. See [ts-hummingbird-1x-types-in-2x-project.md](../troubleshooting/ts-hummingbird-1x-types-in-2x-project.md).
- **Registering routes before middleware** → routes not covered by middleware. See [ts-hummingbird-middleware-not-applied.md](../troubleshooting/ts-hummingbird-middleware-not-applied.md).
- **Using `.convertFromSnakeCase` with explicit `CodingKeys`** → decode fails. See [ts-keynotfound-during-codable-decode.md](../troubleshooting/ts-keynotfound-during-codable-decode.md).
- **Not emitting the SSE terminator on error paths** → SSE clients hang.

## Exercise

Complete [lab-06-hummingbird-echo.md](../labs/lab-06-hummingbird-echo.md): build a Hummingbird server with `POST /echo`.

## Recap

- Hummingbird 2.x: `Router()`, `Application(router:configuration:)`, `try await app.runService()`.
- No Hummingbird 1.x types (`HBApplication`, `HBRequest`, etc.).
- Middleware registration is positional — add before routes it should cover.
- Decode bodies manually with a plain `JSONDecoder()`.
- SSE: `ResponseBody { writer in ... }`, headers `text/event-stream`, emit terminator on all code paths.
- In-process tests with `app.test(.router)` or `.live`. URLSession needs a separate helper.
