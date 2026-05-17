# Playbook: expose Claude as an HTTP service (sync + streaming SSE) using Hummingbird 2

**Goal**: A Hummingbird 2.x server exposing `GET /health`, `POST /chat`, and `POST /chat/stream` that proxies to Anthropic via the L2 client.

## Prerequisites
- L2 `AnthropicClient` available as a sibling SwiftPM package or git dependency.
- macOS 14+ (Hummingbird 2.x requires it on the host).

## Steps

1. Add Hummingbird to `Package.swift`:
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

2. Define an `LLMService` protocol locally (don't import L3) and conform `AnthropicClient`:
   ```swift
   public protocol LLMService: Sendable {
       func send(_ request: MessageRequest) async throws -> Message
       func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error>
   }
   extension AnthropicClient: LLMService {}
   ```

3. Build the router. **Register middleware before routes** (see gotcha `gotchas/hummingbird-middleware-only-applies-to-routes-added-after.md`). Decode `MessageRequest` with a plain `JSONDecoder()` — not snake_case strategy (see gotcha `gotchas/snake-case-codable-double-transform.md`):

   ```swift
   public func buildRouter(service: any LLMService) -> Router<BasicRequestContext> {
       let router = Router()
       router.middlewares.add(LogRequestsMiddleware(.info))      // <-- first

       router.get("/health") { _, _ -> Response in
           Response(status: .ok,
                    headers: [.contentType: "application/json"],
                    body: .init(byteBuffer: ByteBuffer(string: #"{"status":"ok"}"#)))
       }

       let requestDecoder = JSONDecoder()        // plain — MessageRequest has explicit CodingKeys

       router.post("/chat") { req, _ async throws -> Response in
           let data = try await collectBodyData(req)
           let payload = try requestDecoder.decode(MessageRequest.self, from: data)
           do {
               let message = try await service.send(payload)
               let body = try JSONEncoder.snake.encode(message)
               return Response(status: .ok,
                               headers: [.contentType: "application/json"],
                               body: .init(byteBuffer: ByteBuffer(bytes: body)))
           } catch let e as AnthropicError {
               return mapAnthropicError(e)               // typed mapping
           }
       }

       router.post("/chat/stream") { req, _ async throws -> Response in
           // ... see pattern patterns/hummingbird-streaming-response-body.md
       }
       return router
   }
   ```

4. For the streaming route, use the canonical `ResponseBody { writer in ... }` shape from pattern `patterns/hummingbird-streaming-response-body.md`.

5. Map `AnthropicError` cases to HTTP statuses including forwarded `Retry-After` (see pattern `patterns/typed-error-enum-with-bodies.md`).

6. Wire `main`:
   ```swift
   @main
   struct ToolServer {
       static func main() async throws {
           guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
               FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
               exit(1)
           }
           let client = AnthropicClient(apiKey: apiKey)
           let router = buildRouter(service: client)
           let app = Application(
               router: router,
               configuration: .init(address: .hostname("0.0.0.0", port: 8080),
                                    serverName: "tool-server")
           )
           try await app.runService()
       }
   }
   ```

7. Test in-process with `HummingbirdTesting`:
   ```swift
   try await app.test(.router) { client in
       try await client.execute(uri: "/chat", method: .post,
                                headers: [.contentType: "application/json"],
                                body: ByteBuffer(string: requestBody)) { response in
           #expect(response.status == .ok)
       }
   }
   ```

8. Smoke from a shell:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-... swift run tool-server
   curl -X POST localhost:8080/chat -H 'content-type: application/json' \
        -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":1024,"messages":[{"role":"user","content":"hi"}]}'
   curl -X POST localhost:8080/chat/stream -H 'content-type: application/json' \
        -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":1024,"messages":[{"role":"user","content":"count to 3"}]}'
   ```

## You'll know it worked when…
- `swift test` passes all four endpoint tests with the mock service.
- `curl /health` returns `{"status":"ok"}`.
- `curl /chat` returns a single JSON Message.
- `curl -N /chat/stream` streams `data: <text>\n\n` frames followed by `event: done\ndata: [DONE]\n\n`.
- `kill -TERM <pid>` drains in-flight requests and exits 0.

## Evidence
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:107-206` — full router with all three routes.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/LLMService.swift:12-17` — local protocol seam.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/ErrorBody.swift:7-15` — unified JSON error shape.
- POC: `L4-hummingbird-tool-service/Sources/tool-server/main.swift:12-29` — entry point.
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/` — 16 tests including HealthTests, ChatEndpointTests, ChatStreamEndpointTests, ErrorMappingTests, Regression.
- Research: `01-research/04-hummingbird.md` §1-§11 — Hummingbird 2.x reference.
- See also: gotcha `gotchas/hummingbird-1x-syntax-does-not-compile-on-2x.md`, before-you-build `before-you-build/hummingbird-service.md`.
