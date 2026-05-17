# Lab 3 — Protocol-Injected HTTP Mock

[Back to index](../index.md) | Lesson: [lesson-04-http-transport-seam.md](../lessons/lesson-04-http-transport-seam.md)

## Task

Implement a miniature `WeatherClient` that fetches temperature data over HTTP, with a protocol seam for testability and a mock transport.

## Deliverables

- `Sources/WeatherLib/HTTPTransport.swift` — the protocol + `URLSessionTransport`
- `Sources/WeatherLib/WeatherClient.swift` — the typed client
- `Sources/WeatherLib/Models.swift` — `WeatherResponse: Codable, Sendable, Equatable`
- `Tests/WeatherLibTests/MockHTTPTransport.swift` — mock
- `Tests/WeatherLibTests/WeatherClientTests.swift` — tests with zero network calls
- `swift test` exits 0

## Starter `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "WeatherLib",
    platforms: [.macOS(.v13)],
    products: [.library(name: "WeatherLib", targets: ["WeatherLib"])],
    targets: [
        .target(name: "WeatherLib"),
        .testTarget(name: "WeatherLibTests", dependencies: ["WeatherLib"]),
    ]
)
```

## Requirements

### `HTTPTransport` protocol

```swift
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```

### `WeatherResponse`

Decodes from this JSON:
```json
{"temperature_celsius": 22.5, "city": "London", "condition": "cloudy"}
```

Use explicit `CodingKeys` with snake_case values.

### `WeatherClient`

```swift
public struct WeatherClient: Sendable {
    public let transport: any HTTPTransport
    public init(transport: any HTTPTransport = URLSessionTransport())

    public func fetchTemperature(city: String) async throws -> WeatherResponse
}
```

- Builds a `GET` request to `https://api.example-weather.com/current?city=<city>`.
- Maps HTTP 401 → a `WeatherError.unauthorized` typed error.
- Maps HTTP 429 → `WeatherError.rateLimited`.
- Maps HTTP 200 + body → decoded `WeatherResponse`.

### `MockHTTPTransport`

Must be `final class`, `@unchecked Sendable`, hold a configurable `(Data, HTTPURLResponse)` response, and record captured requests.

## Required tests

1. HTTP 200 → `WeatherResponse` decoded correctly.
2. HTTP 401 → `WeatherError.unauthorized` thrown.
3. HTTP 429 → `WeatherError.rateLimited` thrown.
4. Captured request has the correct `city` query parameter.

## Verification

```bash
swift test
```

<details>
<summary>Hint</summary>

```swift
final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    var response: (Data, HTTPURLResponse)?
    var capturedRequests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequests.append(request)
        return response!
    }
}
```

Build the mock response in your test:
```swift
let mock = MockHTTPTransport()
let json = #"{"temperature_celsius": 22.5, "city": "London", "condition": "cloudy"}"#
let data = Data(json.utf8)
let http = HTTPURLResponse(url: URL(string: "http://x")!, statusCode: 200,
                           httpVersion: nil, headerFields: nil)!
mock.response = (data, http)
```

</details>
