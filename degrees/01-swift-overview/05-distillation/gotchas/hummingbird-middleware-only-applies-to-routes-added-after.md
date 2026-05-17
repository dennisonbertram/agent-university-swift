# Hummingbird middleware applies ONLY to routes registered AFTER `middlewares.add(_:)` — not globally

**Category**: gotcha

## What
In Hummingbird 2, `router.middlewares.add(myMiddleware)` is positional: it wraps only routes registered AFTER the call. Routes registered before the call do not see the middleware. Many frameworks register middleware globally; Hummingbird does not.

## Symptom
- An `AuthMiddleware` ignores `/health` because health was registered first — but ALSO ignores `/chat` if you forgot to call `middlewares.add()` before declaring `router.post("/chat")`.
- Tests for the auth path pass; a route added later sees no auth.

## Cause
`router.middlewares.add()` mutates an internal chain that is captured when each subsequent route is registered. The Hummingbird source's doc comment is explicit: "Middleware is applied only to endpoints registered after the `add(middleware:)` call."

## Fix
Register middleware **first**, then routes. The canonical order:

```swift
public func buildRouter(service: any LLMService) -> Router<BasicRequestContext> {
    let router = Router()
    router.middlewares.add(LogRequestsMiddleware(.info))   // <-- first
    // Then routes:
    router.get("/health") { _, _ in /* ... */ }
    router.post("/chat") { req, _ in /* ... */ }
    return router
}
```

If some routes legitimately should not have a middleware (e.g. `/health` exempt from auth), register the exempt routes before adding the middleware, then add the middleware, then register the rest.

## Evidence
- Research: `01-research/04-hummingbird.md` §7 lines 272-276 — "IMPORTANT: middleware applies to routes registered AFTER the add() call."
- Research: `01-research/06-expectation-gaps.md` EG-14 lines 262-268 — "Middleware Order Is Not Global in Hummingbird 2."
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:107-119` — `Router()` → `middlewares.add(LogRequestsMiddleware)` → all GET/POST registrations follow.
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/Router.swift:103-114` — same pattern: middleware first, then `/health`, `/chat`, `/chat/stream`.
