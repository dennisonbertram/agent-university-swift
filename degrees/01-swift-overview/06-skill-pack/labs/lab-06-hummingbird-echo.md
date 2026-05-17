# Lab 6 — Hummingbird Echo Server

[Back to index](../index.md) | Lesson: [lesson-07-hummingbird-http-services.md](../lessons/lesson-07-hummingbird-http-services.md)

## Task

Build a Hummingbird 2.x server with a `POST /echo` route that JSON-decodes a body and echoes it back, plus `GET /health`.

## Deliverables

- `Sources/EchoService/Router.swift` — `buildRouter()` function
- `Sources/echo-server/main.swift` — `Application` init + `runService()`
- `Tests/EchoServiceTests/EchoTests.swift` — in-process tests
- `swift test` exits 0
- `curl -X POST localhost:8080/echo -H 'content-type: application/json' -d '{"message":"hi"}' ` → `{"message":"hi","echoed":true}`

## Starter `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "EchoServer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0")
    ],
    targets: [
        .target(name: "EchoService",
                dependencies: [.product(name: "Hummingbird", package: "hummingbird")]),
        .executableTarget(name: "echo-server", dependencies: ["EchoService"]),
        .testTarget(name: "EchoServiceTests",
                    dependencies: [
                        "EchoService",
                        .product(name: "HummingbirdTesting", package: "hummingbird")
                    ]),
    ]
)
```

## Request and response types

```swift
struct EchoRequest: Codable {
    var message: String
}

struct EchoResponse: Codable {
    var message: String
    var echoed: Bool
}
```

## Requirements

### `GET /health`

Returns HTTP 200 with body `{"status":"ok"}`.

### `POST /echo`

1. Collect the request body (up to 1 MB).
2. Decode as `EchoRequest` using a plain `JSONDecoder()`.
3. Return HTTP 200 with an `EchoResponse` where `message` is the same as the input and `echoed` is `true`.
4. On decode failure, return HTTP 400 with a body describing the error.

### Middleware

Register `LogRequestsMiddleware(.info)` before both routes.

## Required tests

```swift
@Test("GET /health returns 200")
func healthCheck() async throws { /* app.test(.router) */ }

@Test("POST /echo echoes the message")
func echoMessage() async throws { /* post JSON, check response body */ }

@Test("POST /echo with invalid JSON returns 400")
func echoInvalidJSON() async throws { /* post garbage, check 400 */ }
```

Use `app.test(.router)` for all tests.

## Verification

```bash
swift test
swift run echo-server &
curl http://localhost:8080/health
curl -X POST http://localhost:8080/echo \
     -H 'content-type: application/json' \
     -d '{"message":"hello, Hummingbird!"}'
kill %1
```

<details>
<summary>Hint</summary>

Body collection helper:

```swift
func collectBodyData(_ req: Request) async throws -> Data {
    let buffer = try await req.body.collect(upTo: 1024 * 1024)
    return Data(buffer: buffer)
}
```

Route handler:
```swift
router.post("/echo") { req, _ async throws -> Response in
    let data = try await collectBodyData(req)
    guard let payload = try? JSONDecoder().decode(EchoRequest.self, from: data) else {
        return Response(status: .badRequest,
                        headers: [.contentType: "application/json"],
                        body: .init(byteBuffer: ByteBuffer(string: #"{"error":"invalid JSON"}"#)))
    }
    let response = EchoResponse(message: payload.message, echoed: true)
    let responseData = try JSONEncoder().encode(response)
    return Response(status: .ok,
                    headers: [.contentType: "application/json"],
                    body: .init(byteBuffer: ByteBuffer(bytes: responseData)))
}
```

</details>
