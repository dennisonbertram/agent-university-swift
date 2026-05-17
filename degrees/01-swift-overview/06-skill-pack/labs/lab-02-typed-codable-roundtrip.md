# Lab 2 — Typed Codable Round-Trip

[Back to index](../index.md) | Lesson: [lesson-03-typed-clients-with-codable.md](../lessons/lesson-03-typed-clients-with-codable.md)

## Task

Write a `User` Codable struct with snake_case keys and prove it round-trips correctly through JSON encoding and decoding.

## Deliverables

- `Sources/UserLib/User.swift` — `Codable, Sendable, Equatable` struct
- `Tests/UserLibTests/UserCodableTests.swift` — round-trip + key-shape tests
- `swift test` exits 0

## Starter `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "UserLib",
    platforms: [.macOS(.v13)],
    products: [.library(name: "UserLib", targets: ["UserLib"])],
    targets: [
        .target(name: "UserLib"),
        .testTarget(name: "UserLibTests", dependencies: ["UserLib"]),
    ]
)
```

## Requirements

The `User` type must:

1. Have these Swift properties:
   - `firstName: String`
   - `lastName: String`
   - `emailAddress: String`
   - `createdAt: String`
   - `isActive: Bool`

2. Encode to JSON with snake_case keys:
   - `"first_name"`, `"last_name"`, `"email_address"`, `"created_at"`, `"is_active"`

3. NOT use `keyDecodingStrategy = .convertFromSnakeCase` on the decoder — use explicit `CodingKeys`.

## Required tests

1. Encode a `User` to JSON; assert the encoded keys are snake_case.
2. Decode a JSON string with snake_case keys into a `User`; assert field values are correct.
3. Encode and decode round-trip; assert `encoded == decoded`.
4. Demonstrate that decoding fails when using `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` (because of double-transform — or document why it would silently break).

## Input JSON for decoding test

```json
{
  "first_name": "Alice",
  "last_name": "Smith",
  "email_address": "alice@example.com",
  "created_at": "2024-01-15T10:30:00Z",
  "is_active": true
}
```

## Verification

```bash
swift test
```

<details>
<summary>Hint</summary>

```swift
public struct User: Codable, Sendable, Equatable {
    public var firstName: String
    public var lastName: String
    public var emailAddress: String
    public var createdAt: String
    public var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case firstName    = "first_name"
        case lastName     = "last_name"
        case emailAddress = "email_address"
        case createdAt    = "created_at"
        case isActive     = "is_active"
    }
}
```

Decode with `JSONDecoder()` (no strategy):
```swift
let user = try JSONDecoder().decode(User.self, from: jsonData)
```

</details>
