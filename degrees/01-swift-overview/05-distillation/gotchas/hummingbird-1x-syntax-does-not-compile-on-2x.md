# Hummingbird 1.x and 2.x are completely incompatible — `HBApplication` / `HBRequest` does not exist in 2.x

**Category**: gotcha

## What
Hummingbird 2.x is a ground-up redesign. There is no `HB` prefix on any type, no `EventLoopFuture` return type, no `HBMiddleware` protocol. LLM training data from before mid-2024 produces 1.x code that does not compile at all against the current 2.0+ release.

## Symptom
```
error: cannot find 'HBApplication' in scope
error: cannot find type 'HBRequest' in scope
error: cannot find type 'HBMiddleware' in scope
```

## Cause
Hummingbird 2 was released in 2024 with a complete API change to embrace Swift's structured concurrency. Old tutorials, Stack Overflow answers, and any LLM trained before that period output 1.x syntax.

## Fix
Use 2.x patterns. Quick reference:

| Hummingbird 1.x (do NOT use)              | Hummingbird 2.x (correct)                                                |
|-------------------------------------------|--------------------------------------------------------------------------|
| `let app = HBApplication(configuration:)` | `let router = Router(); let app = Application(router: router, configuration: ...)` |
| `app.router.get("/x") { req in ... }`     | `router.get("/x") { req, ctx -> Response in ... }`                       |
| `(HBRequest) -> EventLoopFuture<HBResponse>` | `(Request, Context) async throws -> ResponseType`                     |
| `HBMiddleware` protocol                    | `RouterMiddleware` / `MiddlewareProtocol`                                |
| `app.start(); app.wait()`                  | `try await app.runService()`                                             |

Canonical minimum:

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

## Evidence
- Research: `01-research/04-hummingbird.md` §10 lines 338-353 — full breaking-changes table.
- Research: `01-research/06-expectation-gaps.md` EG-03 lines 58-77 — "Complete Incompatibility".
- Probe: `/tmp/swift-research-probe/hb-test/` — Hummingbird 2.23.0 builds with the 2.x API.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:108-118` — canonical 2.x usage: `Router()`, `router.middlewares.add(...)`, `router.get(...) { _, _ -> Response in ... }`.
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/main.swift:14-15` — `try await app.runService()`.
- See also: before-you-build `before-you-build/hummingbird-service.md`.
