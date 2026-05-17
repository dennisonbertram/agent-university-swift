# Before-you-build: Hummingbird HTTP service

Tick every box before adding a new Hummingbird 2.x route or service.

## Version
- [ ] You are on Hummingbird **2.x**, not 1.x. There is no `HBApplication`, `HBRequest`, `HBMiddleware`, or `EventLoopFuture` in 2.x (see gotcha `gotchas/hummingbird-1x-syntax-does-not-compile-on-2x.md`). Pin `from: "2.0.0"`.
- [ ] Host platform is macOS 14+ or Linux. Hummingbird 2 requires Swift 6.1+ and modern structured concurrency.

## Application setup
- [ ] You construct `Router()` first, then `Application(router: router, configuration: ...)` — not `HBApplication(...)`.
- [ ] Address is `.hostname("127.0.0.1", port: 8080)` for local, `.hostname("0.0.0.0", port: 8080)` to bind all interfaces, `.hostname("127.0.0.1", port: 0)` for tests where you want an OS-assigned port.
- [ ] Lifecycle is `try await app.runService()` — this handles SIGTERM/SIGINT graceful shutdown via `ServiceGroup`.

## Routing
- [ ] Middleware is registered **before** the routes it should apply to. The middleware chain is positional, not global (see gotcha `gotchas/hummingbird-middleware-only-applies-to-routes-added-after.md`).
- [ ] Handler signature is `(Request, Context) async throws -> R` where `R: ResponseGenerator` (`String`, `HTTPResponse.Status`, your `Codable & ResponseCodable` types, or `Response` for full control).

## Request decoding
- [ ] You decode JSON with a plain `JSONDecoder()` for types that declare snake_case `CodingKeys`. Do NOT add `.convertFromSnakeCase` on top of explicit keys (see gotcha `gotchas/snake-case-codable-double-transform.md`).
- [ ] Body collection uses `try await req.body.collect(upTo: 2 * 1024 * 1024)` (or your size limit). Bodies are streaming by default; you must opt in to collection.

## Streaming responses (SSE / chunked)
- [ ] You use the `ResponseBody { writer in ... }` closure (see pattern `patterns/hummingbird-streaming-response-body.md`).
- [ ] Headers include `.contentType: "text/event-stream"` and ideally `.cacheControl: "no-cache"`.
- [ ] Every code path emits a terminator before `writer.finish(nil)`. Both happy-path and stream-ended-early fallback.

## Error mapping
- [ ] Typed domain errors map to specific HTTP statuses. 401 → `.unauthorized`, 429 → `.tooManyRequests` with `Retry-After` header forwarded, upstream 5xx → `.badGateway` (502 — distinguishes proxy errors from upstream errors).
- [ ] Error body is uniform: `{"error":"<code>","detail":"<message>"}` via a `ErrorBody: Codable, ResponseCodable` type.

## Tests
- [ ] Tests use `HummingbirdTesting` with either `app.test(.router)` (no socket, fastest) or `app.test(.live)` (NIO test transport).
- [ ] If your test needs `URLSession` (e.g. you're testing a `BackendLLMService` that uses URLSession), you use a custom helper that starts the app on port 0 and captures the OS-assigned port via `onServerRunning` (see gotcha `gotchas/hummingbird-test-live-vs-router-transport.md`).

## Evidence
- Research: `01-research/04-hummingbird.md` §1-§12 — full reference.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:107-206` — canonical router.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/TestFixtures.swift:57-105` — `withLiveBackendForURLSession`.
- See also: playbook `playbooks/playbook-expose-llm-as-http-service.md`.
