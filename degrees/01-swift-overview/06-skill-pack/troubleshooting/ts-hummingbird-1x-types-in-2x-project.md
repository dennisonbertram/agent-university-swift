# Troubleshooting — `cannot find 'HBApplication' in scope`

[Back to index](../index.md)

## Symptom

```
error: cannot find 'HBApplication' in scope
error: cannot find type 'HBRequest' in scope
error: cannot find type 'HBMiddleware' in scope
error: type 'EventLoopFuture' has no member '...'
```

## Diagnosis

You are using Hummingbird 1.x API against the Hummingbird 2.x package. These types do not exist in 2.x. LLM training data from before mid-2024 produces 1.x code.

## Fix

Hummingbird 2.x equivalents:

| Hummingbird 1.x (do NOT use) | Hummingbird 2.x (correct) |
|------------------------------|--------------------------|
| `HBApplication(configuration:)` | `Router()` + `Application(router: router, configuration: ...)` |
| `app.router.get("/x") { req in ... }` | `router.get("/x") { req, ctx -> ResponseType in ... }` |
| `(HBRequest) -> EventLoopFuture<HBResponse>` | `(Request, Context) async throws -> ResponseType` |
| `HBMiddleware` protocol | `RouterMiddleware` / `MiddlewareProtocol` |
| `app.start(); app.wait()` | `try await app.runService()` |
| `HBHTTPResponse` | `Response` |

Minimal correct 2.x pattern:

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

## See also

- Distillation: `gotchas/hummingbird-1x-syntax-does-not-compile-on-2x.md`
- ADR: `decision-records/adr-001-hummingbird-over-vapor.md`
- Lesson: [lesson-07-hummingbird-http-services.md](../lessons/lesson-07-hummingbird-http-services.md)
- Before-you-build: `before-you-build/hummingbird-service.md`
