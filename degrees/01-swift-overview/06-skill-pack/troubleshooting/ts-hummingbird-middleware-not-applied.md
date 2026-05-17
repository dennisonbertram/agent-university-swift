# Troubleshooting — Hummingbird Middleware Not Applied to a Route

[Back to index](../index.md)

## Symptom

A route is not processed by middleware you added. Auth middleware does not fire. Logging middleware shows no log lines for that route. The route responds as if middleware was absent.

## Diagnosis

Hummingbird 2's middleware chain is positional. `router.middlewares.add(myMiddleware)` only applies to routes registered **after** that call. Routes registered before the `add` call do not see the middleware.

## Fix

Register middleware first, then routes:

```swift
public func buildRouter(service: any LLMService) -> Router<BasicRequestContext> {
    let router = Router()

    // ✅ Middleware FIRST
    router.middlewares.add(LogRequestsMiddleware(.info))
    router.middlewares.add(AuthMiddleware())

    // ✅ Routes AFTER
    router.get("/health") { _, _ in /* ... */ }
    router.post("/chat") { req, _ in /* ... */ }
    router.post("/chat/stream") { req, _ in /* ... */ }

    return router
}
```

If some routes should NOT be covered by a middleware (e.g. `/health` is exempt from auth):

```swift
let router = Router()
// Health registered BEFORE auth — exempt from AuthMiddleware
router.get("/health") { _, _ in /* ... */ }

// Now add auth
router.middlewares.add(AuthMiddleware())

// These routes ARE covered by auth
router.post("/chat") { req, _ in /* ... */ }
```

## See also

- Distillation: `gotchas/hummingbird-middleware-only-applies-to-routes-added-after.md`
- Lesson: [lesson-07-hummingbird-http-services.md](../lessons/lesson-07-hummingbird-http-services.md)
- Before-you-build: `before-you-build/hummingbird-service.md`
