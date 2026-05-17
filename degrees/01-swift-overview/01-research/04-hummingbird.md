# Hummingbird 2.x — Swift HTTP Server Framework

> Current version: 2.23.0 (released May 13, 2026)
> GitHub: https://github.com/hummingbird-project/hummingbird
> Swift requirement: 6.1+ (per Package@swift-6.1.swift manifest)
> Verified with: runtime probe `/tmp/swift-research-probe/hb-test/` — Build complete! (61.91s)

---

## 1. Mental Model

Hummingbird 2 is built on top of SwiftNIO (the Apple event-loop library). The architecture:

```
Request → Router → [Middleware chain] → Route Handler → Response
```

Key abstractions:
- **Router**: matches URL paths to handlers; implements `HTTPResponderBuilder`
- **Application**: wraps a responder + configuration + services; conforms to SwiftNIO `Service`
- **Context**: per-request object carrying route parameters, logger, request metadata
- **Middleware**: `(Request, Context, next) → Response` — wraps handler chain
- **ServiceGroup** (from `ServiceLifecycle`): manages `Application` lifecycle + graceful shutdown

Hummingbird 2 is **fully structured-concurrency native**. Handlers are `async throws`. The framework is `Sendable`-clean and designed for Swift 6.

---

## 2. Package.swift Dependency

```swift
dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
],
targets: [
    .executableTarget(
        name: "MyServer",
        dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
        ]
    )
]
```

Source: https://github.com/hummingbird-project/hummingbird README (accessed 2026-05-16)

**Transitive dependencies** (verified from `swift package show-dependencies` on the probe):
- `swift-nio` 2.99.0
- `swift-log` 1.12.0
- `swift-metrics` 2.10.1
- `swift-collections` 1.5.1
- `swift-async-algorithms` 1.1.3
- `swift-http-types` 1.5.1
- `swift-distributed-tracing` 1.4.1

Source: runtime probe dependency tree output.

---

## 3. Application Setup

### Canonical pattern (verified compiles and links)

```swift
import Hummingbird

// 1. Create router
let router = Router()

// 2. Add middleware (applied to all routes registered after this call)
router.middlewares.add(LogRequestMiddleware(.info))

// 3. Add routes
router.get("hello") { request, context -> String in
    return "Hello, Hummingbird!"
}

// 4. Create Application — convenience init accepts a Router directly
let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)

// 5. Run (blocks until SIGINT or SIGTERM)
try await app.runService()
```

Source: Application.swift source (read from probe checkout), lines 243-271 — `init(router:)` convenience init exists and calls `buildResponder()`.

### Application init signatures

```swift
// Full form (uses a built responder)
public init(
    responder: Responder,
    server: HTTPServerBuilder = .http1(),
    configuration: ApplicationConfiguration = ApplicationConfiguration(),
    services: [any Service] = [],
    onServerRunning: @escaping @Sendable (any Channel) async -> Void = { _ in },
    eventLoopGroupProvider: EventLoopGroupProvider = .singleton,
    logger: Logger? = nil
)

// Convenience form (accepts any HTTPResponderBuilder, including Router)
public init<ResponderBuilder: HTTPResponderBuilder>(
    router: ResponderBuilder,
    server: HTTPServerBuilder = .http1(),
    configuration: ApplicationConfiguration = .init(),
    ...
)
```

Source: `/tmp/swift-research-probe/hb-test/.build/checkouts/hummingbird/Sources/Hummingbird/Application.swift` lines 215-271.

### ApplicationConfiguration

```swift
public struct ApplicationConfiguration: Sendable {
    public var address: BindAddress    // default: .hostname() → 127.0.0.1:8080
    public var serverName: String?
    public var backlog: Int            // default: 256
    public var reuseAddress: Bool      // default: true

    // Convenient address forms:
    // .hostname("0.0.0.0", port: 8080)   — all interfaces
    // .hostname()                          — 127.0.0.1:8080 (default)
    // .unixDomainSocket(path: "/tmp/x")   — Unix domain socket
}
```

---

## 4. Router API

```swift
let router = Router()

// HTTP method routes
router.get("/items")        { req, ctx -> [Item] in ... }
router.post("/items")       { req, ctx -> Item in ... }
router.put("/items/:id")    { req, ctx -> Item in ... }
router.delete("/items/:id") { req, ctx -> HTTPResponse.Status in .ok }
router.patch("/items/:id")  { req, ctx -> Item in ... }
router.head("/items")       { req, ctx -> Response in ... }

// Route groups (shared prefix)
router.group("api/v1") { group in
    group.get("users") { req, ctx in ... }
    group.post("users") { req, ctx in ... }
}

// Path parameters
router.get("users/:id") { req, ctx -> User in
    let id = try ctx.parameters.require("id")  // String
    let numId = try ctx.parameters.require("id", as: Int.self)  // typed
    return try await userStore.fetch(id: numId)
}

// Wildcard
router.get("files/*") { req, ctx -> Response in ... }
```

### Router options

```swift
let router = Router(options: [.caseInsensitive, .autoGenerateHeadEndpoints])
```

---

## 5. Handler Signatures and Response Types

Handlers are closures `(Request, Context) async throws -> R` where `R` conforms to `ResponseGenerator`.

```swift
// String → 200 OK with text/plain body
router.get("hello") { req, ctx -> String in "Hello" }

// Encodable type → 200 OK with application/json body (requires encoder configured)
router.get("user") { req, ctx -> User in User(name: "Alice", age: 30) }

// HTTPResponse.Status → status code with empty body
router.delete("item/:id") { req, ctx -> HTTPResponse.Status in .noContent }

// Response → full control
router.get("custom") { req, ctx -> Response in
    Response(
        status: .ok,
        headers: HTTPFields([.contentType: "text/html; charset=utf-8"]),
        body: .init(byteBuffer: ByteBuffer(string: "<h1>Hello</h1>"))
    )
}
```

**ResponseCodable protocol** (verified from source):
```swift
// ResponseEncodable = Encodable + ResponseGenerator
// ResponseCodable = ResponseEncodable + Decodable

// Annotate your model types:
struct User: Codable, ResponseCodable {
    let name: String
    let age: Int
}
// Now User can be returned directly from handlers AND decoded from request body
```

Source: `/tmp/swift-research-probe/hb-test/.build/checkouts/hummingbird/Sources/Hummingbird/Codable/ResponseEncodable.swift`

---

## 6. JSON Request Body Decoding

Hummingbird extends `JSONDecoder` and `JSONEncoder` to conform to `RequestDecoder` / `ResponseEncoder`:

```swift
// Source: JSONCoding.swift
extension JSONEncoder: ResponseEncoder { /* ... */ }
extension JSONDecoder: RequestDecoder { /* ... */ }
```

To use JSON decoding, you need an **Application with a decoder configured** or use `Request.decode`:

```swift
// Option 1: Application with decoder (automatic for ResponseCodable types)
let app = Application(
    router: router,
    configuration: .init()
)
// Routes returning ResponseCodable types are automatically JSON-encoded

// Option 2: Manual decode in handler
router.post("users") { req, ctx -> User in
    let newUser = try await req.decode(as: User.self, context: ctx)
    return newUser
}
```

**Note**: The `decode(as:context:)` uses `context.maxUploadSize` to limit body collection (default: 2MB). Configure in context if needed.

Source: JSONCoding.swift from probe checkout (verified).

**Verified compile**: the probe `hb-test` with `ResponseCodable` struct returned from handler and `req.decode` compiles successfully.

---

## 7. Middleware

```swift
// MiddlewareProtocol:
// func handle(_ input: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response

// RouterMiddleware = MiddlewareProtocol<Request, Response, Context>

// Custom middleware
struct AuthMiddleware: RouterMiddleware {
    typealias Context = BasicRequestContext
    
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        guard let token = request.headers[.authorization] else {
            throw HTTPError(.unauthorized)
        }
        // validate token...
        return try await next(request, context)
    }
}

// Attach middleware to router
router.middlewares.add(AuthMiddleware())
router.middlewares.add(LogRequestMiddleware(.info))  // built-in

// IMPORTANT: middleware applies to routes registered AFTER the add() call
router.middlewares.add(AuthMiddleware())  // applies to routes below
router.get("protected") { ... }          // gets AuthMiddleware
// Routes registered before add() do NOT get the middleware
```

**Built-in middleware** (from source scan):
- `LogRequestMiddleware` — request logging
- `FileMiddleware` — static file serving
- `CORSMiddleware` — CORS headers
- `MetricsMiddleware` — metrics/tracing
- `TracingMiddleware` — distributed tracing

Source: `/tmp/swift-research-probe/hb-test/.build/checkouts/hummingbird/Sources/Hummingbird/Middleware/` directory listing.

---

## 8. Structured Logging

Hummingbird uses `swift-log` (the Apple logging package). Logger is available in every context:

```swift
router.get("hello") { req, context -> String in
    context.logger.info("Handling hello request", metadata: [
        "path": "\(req.uri.path)"
    ])
    return "Hello!"
}
```

Log level is set via `LOG_LEVEL` environment variable (checked in `Application.init`):

```swift
// From Application.swift source:
if let logLevel = Environment().get("LOG_LEVEL").flatMap({ Logger.Level(rawValue: $0) }) {
    logger.logLevel = logLevel
}
// LOG_LEVEL=debug swift run MyServer
```

---

## 9. Running and Graceful Shutdown

```swift
// Graceful shutdown on SIGTERM and SIGINT (Ctrl-C)
try await app.runService()

// Custom signals:
try await app.runService(gracefulShutdownSignals: [.sigterm, .sigint, .sighup])

// For testing — use HummingbirdTesting (separate product):
// .product(name: "HummingbirdTesting", package: "hummingbird")
let app = Application(router: router)
try await app.test(.router) { client in
    let response = try await client.execute(uri: "/hello", method: .get)
    XCTAssertEqual(response.status, .ok)
}
```

`runService()` wraps the application in a `ServiceGroup` from `ServiceLifecycle`, which handles SIGTERM → graceful drain → shutdown.

Source: Application.swift lines 157-166.

---

## 10. Hummingbird 1.x vs 2.x — Breaking Changes

This is a critical expectation gap. Many tutorials and Stack Overflow answers describe Hummingbird 1.x API which is completely different.

| Aspect | Hummingbird 1.x | Hummingbird 2.x |
|--------|----------------|----------------|
| Application init | `HBApplication(configuration:)` | `Application(router:configuration:)` |
| Router creation | `app.router.get(...)` | `let router = Router(); router.get(...)` |
| Handler signature | `HBRequest` | `Request, Context` (two params) |
| Response type | `EventLoopFuture<HBResponse>` | `Response` (direct, async) |
| Middleware protocol | `HBMiddleware` | `RouterMiddleware` / `MiddlewareProtocol` |
| Main prefix | `HB` prefix everywhere | No prefix |
| Swift concurrency | Optional, NIO-based | Native async/await throughout |
| Swift 6 | Not compatible | Fully compatible |

**LLM training data almost certainly mixes v1 and v2 patterns.** Always verify you're using v2 syntax. The definitive signal is whether imports use `HB`-prefixed types (`HBRequest`, `HBApplication`) — if so, it's v1 and should be discarded.

---

## 11. Minimal Complete Example (Verified)

This exact pattern compiled successfully in the runtime probe:

```swift
import Hummingbird

struct User: Codable, ResponseCodable {
    let name: String
    let age: Int
}

struct Greeting: Codable, ResponseCodable {
    let message: String
}

let router = Router()

router.get("hello") { request, context -> String in
    return "Hello, Hummingbird!"
}

router.get("user") { request, context -> User in
    return User(name: "Alice", age: 30)
}

router.post("greet") { request, context -> Greeting in
    let user = try await request.decode(as: User.self, context: context)
    return Greeting(message: "Hello, \(user.name)!")
}

let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)
// try await app.runService()  // uncomment to actually run
```

Source: runtime probe `/tmp/swift-research-probe/hb-test/` — Build complete! (3.69s after first build cached deps).

---

## 12. Failure Modes

### FM-1: Port already in use

**Error**: `bind(): Address already in use (error code 48)`

**Trigger**: running two instances on the same port, or previous process didn't clean up.

**Fix**: `lsof -i :8080 | grep LISTEN` to find and kill the process, or use a different port.

### FM-2: Blocking synchronous work in handlers

Handlers run on NIO event loops. Blocking sync work (disk I/O, CPU-heavy computation) starves other requests.

**Fix**: wrap in `Task.detached` or use `withUnsafeThrowingContinuation` to push to a background thread. Better: use async APIs throughout.

### FM-3: Using Hummingbird 1.x syntax with 2.x

**Error**: various — `HBApplication` not found, `HBRequest` not found, `HBMiddleware` not found.

**Fix**: use 2.x patterns. No `HB` prefix. Router is standalone, not attached to App.

### FM-4: Missing `platforms` in Package.swift

**Error**: `error: 'isolation()' is only available in macOS 10.15 or newer` (in test targets)

**Fix**: add `platforms: [.macOS(.v15)]` to Package.swift.

### FM-5: ResponseCodable without a decoder/encoder configured

If you return a `Codable` type from a route but don't configure JSON encoder on the Application, you may get raw bytes or encoding errors. Hummingbird's default uses `JSONEncoder` for `ResponseCodable` types — this works automatically. But for custom encoders (e.g., `JSONEncoder` with `.iso8601` date strategy), you need to configure the application context.

### FM-6: Middleware ordering matters

Middleware added via `router.middlewares.add()` only applies to **routes registered after** the add call. This is a common mistake when migrating from frameworks where middleware is always global.

---

## Sources

- https://github.com/hummingbird-project/hummingbird — README, version 2.23.0 (accessed 2026-05-16)
- Source files read from probe checkout:
  - `Application.swift` — Application struct, init signatures, runService
  - `Configuration.swift` — ApplicationConfiguration struct
  - `Middleware/Middleware.swift` — MiddlewareProtocol, RouterMiddleware
  - `Codable/CodableProtocols.swift` — ResponseEncoder, RequestDecoder
  - `Codable/JSON/JSONCoding.swift` — JSONEncoder/JSONDecoder conformances
  - `Codable/ResponseEncodable.swift` — ResponseEncodable, ResponseCodable
- Runtime probe `/tmp/swift-research-probe/hb-test/`:
  - `swift package show-dependencies` — resolved version 2.23.0, full dep tree
  - Build complete (JSON routes, ResponseCodable, req.decode) — exit 0
