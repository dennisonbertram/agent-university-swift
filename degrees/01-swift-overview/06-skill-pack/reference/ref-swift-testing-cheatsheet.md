# Reference — swift-testing Cheat Sheet

[Back to index](../index.md)

swift-testing ships bundled with Swift 6. No package dependency needed. `import Testing`.

## Basic test

```swift
import Testing

@Test("Human-readable name")
func myTest() {
    #expect(1 + 1 == 2)
    #expect("hello".count == 5)
    #expect(someOptional != nil)
}
```

## Assertions

| Macro | Use |
|-------|-----|
| `#expect(condition)` | Non-fatal assertion; test continues on failure |
| `#expect(condition, "message")` | With custom failure message |
| `#require(condition)` | Fatal assertion; test stops on failure |
| `let x = try #require(optional)` | Unwrap optional or stop the test |

## Throwing tests

```swift
@Test func parseTest() throws {
    let value = try #require(Int("42"))
    #expect(value == 42)
}

@Test func asyncTest() async throws {
    let result = try await someAsyncWork()
    #expect(result == "expected")
}
```

## Suite (grouping)

```swift
@Suite("Greeter")
struct GreeterTests {
    @Test("Named") func named() { #expect(greet("Bob") == "Hello, Bob!") }
    @Test("Empty") func empty() { #expect(greet("") == "Hello, stranger!") }
}
```

`@Suite` supports `init` for shared setup — run before each `@Test` in the struct.

## Parameterized tests

```swift
@Test("Greet", arguments: [("Alice", "Hello, Alice!"), ("", "Hello, stranger!")])
func greet(name: String, expected: String) {
    #expect(Greeter.greet(name: name) == expected)
}
```

## MainActor-isolated suite (for view model tests)

```swift
@MainActor
@Suite("ChatViewModel")
struct ChatViewModelTests {
    @Test("Increments count") func increment() {
        let vm = ChatViewModel(service: MockLLMService())
        // vm is on @MainActor; test runs on @MainActor
    }
}
```

## Async test with actor

```swift
@Test func actorTest() async throws {
    let actor = ConversationActor()
    await actor.append(role: .user, text: "hi")
    let count = await actor.count()
    #expect(count == 1)
}
```

## Common patterns

```swift
// Expect a specific error
@Test func errorTest() async {
    await #expect(throws: AnthropicError.unauthorized(body: "bad key")) {
        try await client.send(request)
    }
}

// Expect any error
@Test func anyErrorTest() async {
    await #expect(throws: (any Error).self) {
        try await client.send(request)
    }
}
```

Evidence: every POC test target; `01-research/02-swiftpm-and-tooling.md §6`.
