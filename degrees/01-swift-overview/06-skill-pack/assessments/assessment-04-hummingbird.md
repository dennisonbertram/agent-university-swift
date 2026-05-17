# Assessment 4 — Hummingbird HTTP Services

[Back to index](../index.md) | Covers: [lesson-07-hummingbird-http-services.md](../lessons/lesson-07-hummingbird-http-services.md)

## Questions

**Q1.** You have existing Hummingbird code from a tutorial. It uses `HBApplication` and `HBRequest`. Your build fails with:
```
error: cannot find 'HBApplication' in scope
```
What is the cause and what does the 2.x equivalent look like?

**Q2.** You add `LogRequestsMiddleware` and `AuthMiddleware` to your router, then register routes. Your `/health` route works but auth is not enforced on `/chat`. Looking at the code:

```swift
let router = Router()
router.get("/health") { _, _ in /* ... */ }
router.post("/chat") { _, _ in /* ... */ }
router.middlewares.add(LogRequestsMiddleware(.info))
router.middlewares.add(AuthMiddleware())
```

What is wrong?

**Q3.** You write a test using `app.test(.live)` and then add a line that calls the route via `URLSession`. The test hangs. Why, and what is the fix?

**Q4.** An SSE route is returning responses where the SSE client hangs after all tokens arrive. Looking at the route, neither the `messageStop` path nor the error path calls `writer.finish(nil)`. What is the fix?

**Q5.** You decode a request body with:
```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let payload = try decoder.decode(MessageRequest.self, from: data)
```
`MessageRequest` uses explicit `CodingKeys`. What happens at runtime?

<details>
<summary>Answer Key</summary>

**A1.** Cause: you are using Hummingbird 1.x API against the 2.x package. All `HB`-prefixed types were removed in the 2.x redesign. 2.x equivalent:
```swift
let router = Router()
router.get("hello") { _, _ -> String in "Hello!" }
let app = Application(router: router, configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
try await app.runService()
```

**A2.** Middleware registration is positional in Hummingbird 2.x. `middlewares.add(...)` only applies to routes registered AFTER the call. Both routes (`/health` and `/chat`) were registered before the `middlewares.add(...)` calls, so neither sees the middleware. Fix: call `middlewares.add(...)` before registering any routes.

**A3.** `HummingbirdTesting`'s `.live` test client uses NIO's embedded channel, not a real TCP socket. `URLSession` cannot dial it. Fix: use `withLiveBackendForURLSession` which starts the application with `port: 0` and captures the OS-assigned port via `onServerRunning`.

**A4.** The SSE client hangs because the response writer was never finished. Fix: call `try await writer.finish(nil)` on ALL code paths — happy path (after `messageStop`), fallback path (stream ended without `messageStop`), and error path.

**A5.** Decoding breaks with `Key not found`. `.convertFromSnakeCase` transforms `"max_tokens"` → `"maxTokens"` before matching. The `CodingKey` has raw value `"max_tokens"` — the double-transform produces a non-matching key. Fix: use a plain `JSONDecoder()`.

</details>
