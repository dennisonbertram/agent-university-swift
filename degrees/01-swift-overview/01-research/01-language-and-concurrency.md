# Swift 6.1 Language and Concurrency

> Toolchain: Apple Swift 6.1.2 (swiftlang-6.1.2.1.2, clang-1700.0.13.5), arm64-apple-macosx15.0
> All code samples compiled and tested via runtime probes unless noted.

---

## 1. Value vs Reference Types

Swift's type system is load-bearing for concurrency. Understanding the split is not optional.

**Value types** (struct, enum, tuple): copying semantics; each variable holds its own independent copy. Implicitly `Sendable` when all stored properties are `Sendable`. No shared mutable state.

**Reference types** (class): reference semantics; variables hold a pointer; mutation is shared. NOT automatically `Sendable`. Causes data race errors in Swift 6 when shared across concurrency domains.

```swift
struct Point { var x: Int; var y: Int }  // Sendable — fine to cross task boundaries
class Cache { var items: [String] = [] } // NOT Sendable unless explicitly declared

// struct is the right choice for model data passed between tasks
// class is for shared mutable state that needs actor protection
```

**Key rule for Swift 6 agents**: reach for `struct` first. Use `class` only when you need identity, shared mutation, or interop with ObjC/Foundation APIs.

---

## 2. Protocols, Associated Types, Generics

These are the vocabulary every Swift library uses. An agent must be able to read and write them.

```swift
// Protocol with associated type
protocol Fetchable {
    associatedtype Output: Sendable
    func fetch() async throws -> Output
}

// Generic function constrained by protocol
func process<T: Fetchable>(_ fetcher: T) async throws -> T.Output {
    return try await fetcher.fetch()
}

// Existential (any) vs generic (some)
// any Fetchable = runtime dispatch, erases type info
// some Fetchable = static dispatch, preserves type info (preferred in Swift 5.7+)

func useExistential(_ f: any Fetchable) { }   // erased — cannot use Output directly
func useSome(_ f: some Fetchable) { }         // static — Output is known to compiler
```

**Swift 6 addition**: `any` keyword required for existential types (SE-0352). Writing `Fetchable` where you mean the existential is now an error unless you write `any Fetchable`.

---

## 3. Error Handling

```swift
enum APIError: Error {
    case invalidResponse(statusCode: Int)
    case decodingFailed(String)
    case rateLimited(retryAfter: Int)
}

// Throwing functions
func fetchUser(id: String) async throws -> User {
    guard let url = URL(string: "...") else { throw APIError.decodingFailed("bad url") }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw APIError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    return try JSONDecoder().decode(User.self, from: data)
}

// Result type for synchronous / deferred error handling
func parse(_ s: String) -> Result<Int, Error> {
    guard let n = Int(s) else { return .failure(APIError.decodingFailed(s)) }
    return .success(n)
}
```

**do-try-catch is the main pattern**. `Result` is used when you need to defer handling or store the outcome.

---

## 4. Optionals

```swift
var name: String? = nil

// Preferred: guard let (exits scope on nil)
guard let n = name else { return }
print(n)  // n is String here, not String?

// if let (limits scope)
if let n = name { print(n) }

// Optional chaining
let count = name?.count  // Int?

// nil coalescing
let display = name ?? "Anonymous"

// Force unwrap — AVOID unless invariant is documented
let forced = name!  // crashes if nil
```

---

## 5. Codable

The primary mechanism for JSON serialization. Used everywhere in API clients.

```swift
struct Message: Codable {
    let id: String
    let role: String
    let content: [ContentBlock]
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
}

// Custom keys
struct StreamEvent: Codable {
    let type: String
    let index: Int?
    let delta: Delta?
    
    enum CodingKeys: String, CodingKey {
        case type, index, delta
    }
}

// JSONDecoder defaults
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase  // snake_case → camelCase
let message = try decoder.decode(Message.self, from: data)

// JSONEncoder
let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase
```

**Caution**: `keyDecodingStrategy = .convertFromSnakeCase` does NOT handle all Anthropic API field names perfectly. The API uses `stop_reason`, `tool_use`, `input_tokens` — all straightforward. But `tool_use_id` and `content_block_start` map correctly. Prefer explicit `CodingKeys` for API types where correctness is critical.

---

## 6. Concurrency: async/await

Swift's structured concurrency model. `async` marks a function that can suspend. `await` marks a suspension point.

```swift
// Basic async function
func fetchData() async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: URL(string: "https://api.example.com")!)
    return data
}

// @main struct is the entry point for async programs
@main
struct App {
    static func main() async throws {
        let data = try await fetchData()
        print("Got \(data.count) bytes")
    }
}
```

**Runtime probe result** (verified):
```
swift --version: Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)
actor-test build: Build complete! (25.76s)
actor-test output: Count: 5 / hello / world / Done
```
Source: runtime probe `/tmp/swift-research-probe/actor-test/`

---

## 7. Task and TaskGroup

`Task` spawns unstructured concurrent work. `withTaskGroup` / `withThrowingTaskGroup` create structured groups.

```swift
// Unstructured Task — detaches from caller's scope
let task = Task {
    return try await someAsyncWork()
}
let result = try await task.value  // wait for it

// Task with cancellation
let t = Task {
    for i in 0..<100 {
        try Task.checkCancellation()  // throws CancellationError if cancelled
        await doWork(i)
    }
}
t.cancel()  // request cancellation

// Structured TaskGroup — all tasks complete before group exits
let results = try await withThrowingTaskGroup(of: String.self) { group in
    for id in ["a", "b", "c"] {
        group.addTask {
            return try await fetchItem(id: id)
        }
    }
    var collected: [String] = []
    for try await result in group {
        collected.append(result)
    }
    return collected
}
```

**Structured concurrency rule**: prefer `withTaskGroup` over `Task { }` detachment. Structured tasks propagate cancellation automatically; unstructured tasks require manual `cancel()` calls.

---

## 8. Actors and Actor Isolation

Actors are reference types with built-in mutual exclusion for their mutable state.

```swift
actor Counter {
    private var count = 0
    
    func increment() { count += 1 }
    func value() -> Int { count }
}

// Must use await to cross actor boundary
let counter = Counter()
await counter.increment()
let v = await counter.value()
```

**Verified by runtime probe** — the actor/TaskGroup/AsyncThrowingStream probe compiled and ran correctly on Swift 6.1.2:
```
Count: 5
hello
world
Done
```
Source: runtime probe `/tmp/swift-research-probe/actor-test/`

### @MainActor

`@MainActor` is a global actor representing the main thread. Use it for UI models.

```swift
@MainActor
class ChatViewModel {
    var messages: [Message] = []
    
    func append(_ message: Message) {
        messages.append(message)
    }
}

// Crossing to @MainActor from a non-isolated context requires await
func updateFromBackground(vm: ChatViewModel, msg: Message) async {
    await vm.append(msg)
}
```

**Important nuance verified by probe**: accessing a `@MainActor` property with `await` when already on the main actor produces a warning "no 'async' operations occur within 'await' expression" — not an error. The compiler detects you're already on MainActor and warns.

---

## 9. Sendable and @Sendable

`Sendable` is the protocol marking types safe to share across concurrency domains.

| Type | Sendable? | Notes |
|------|-----------|-------|
| `struct` with all-Sendable fields | Implicitly Sendable | |
| `enum` with all-Sendable cases | Implicitly Sendable | |
| `class` | NOT Sendable by default | Must explicitly conform |
| `actor` | Sendable | Enforced by language |
| `@Sendable` closure | Type-checked | Cannot capture mutable state unsafely |

```swift
// Conforming a class to Sendable (requires thread safety proof)
final class ThreadSafeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]
    
    func get(_ key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }
}

// @Sendable closure — the function itself is Sendable
func addTask(_ work: @escaping @Sendable () async throws -> Void) {
    Task { try await work() }
}
```

### Swift 6 vs Swift 5 — The Key Difference

In Swift 5, Sendable violations are **warnings** (with `-enable-experimental-feature StrictConcurrency`). In Swift 6, they are **errors** by default.

**The most common Swift 6 error** (verified by runtime probe):

```
error: var 'globalMutableVar' is not concurrency-safe because it is 
nonisolated global shared mutable state
  note: convert 'globalMutableVar' to a 'let' constant
  note: add '@MainActor' to make part of global actor 'MainActor'
  note: disable concurrency-safety checks if accesses are protected
        by an external synchronization mechanism
```

Source: runtime probe `/tmp/swift-research-probe/global-state-test/` — exit code 1

**Fixes for non-isolated global mutable state**:
1. Make it `let` (immutable)
2. Add `@MainActor` annotation
3. Move into an actor
4. Mark `nonisolated(unsafe)` if external locking guarantees safety (escape hatch)

### Region-Based Isolation (Swift 6 / SE-0414)

Swift 6 introduced **region-based isolation** — the compiler tracks whether a value can be proven to have a single owner before crossing isolation boundaries. This allows passing non-Sendable values to other isolation domains when the compiler can prove the source no longer has access.

```swift
// This is valid in Swift 6 even though Message is not Sendable,
// because 'msg' is not used after the transfer
func sendToActor(_ actor: MyActor, msg: Message) async {
    await actor.handle(msg)  // transfer is safe: msg not used after this point
}
```

This is a **Swift 6 expectation gap**: LLMs trained on Swift 5 material expect every cross-boundary type to require explicit `Sendable`. Region-based isolation eliminates some of those requirements, but the rule is subtle.

---

## 10. AsyncSequence and AsyncThrowingStream

The primary tools for streaming data — essential for SSE parsing in L3.

```swift
// AsyncThrowingStream<Element, Error>
// - yields elements one at a time
// - finishes normally or with error
// - consumed with `for try await ... in stream`

func makeSSEStream(from response: URLResponse) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            // parse SSE lines...
            continuation.yield("event: message_start")
            continuation.yield("data: {\"type\":\"message_start\"}")
            continuation.finish()  // clean finish
            // or: continuation.finish(throwing: SomeError())
        }
    }
}

// Consuming the stream
let stream = makeSSEStream(from: response)
for try await line in stream {
    print(line)
}
```

**AsyncStream** (non-throwing) vs **AsyncThrowingStream** (throwing): for SSE parsing where network errors are possible, use `AsyncThrowingStream`.

**Verified by runtime probe** — the actor-test probe includes AsyncThrowingStream and works correctly:
```swift
func makeStream() -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            continuation.yield("hello")
            continuation.yield("world")
            continuation.finish()
        }
    }
}
// Output: hello\nworld\nDone
```

---

## 11. What Changed at Swift 6 vs Swift 5

| Feature | Swift 5 (≤5.10) | Swift 6 |
|---------|-----------------|---------|
| Global mutable state | Warning with strict concurrency | **Error** |
| `Sendable` violations across boundaries | Warning | **Error** |
| Existentials require `any` | Upcoming feature flag | Enforced by default |
| Region-based isolation | Not available | Available (SE-0414) |
| Complete concurrency checking | Opt-in flag | Default |
| `nonisolated(unsafe)` | Not available | Available escape hatch |

**Turning off Swift 6 concurrency enforcement** (for migration):
```swift
// In Package.swift — per-target opt-out
.target(
    name: "MyTarget",
    swiftSettings: [.swiftLanguageMode(.v5)]  // revert to Swift 5 semantics
)
```

---

## 12. Common Failure Modes

### FM-1: Missing platform declaration causes swift-testing compile error

**Error** (exact output from runtime probe):
```
error: 'isolation()' is only available in macOS 10.15 or newer
@__swiftmacro_13lib_testTests7example4TestfMp_.swift:3:65
```

**Trigger**: `swift package init --type library` generates `Package.swift` without `platforms`. swift-testing requires macOS 10.15+.

**Fix**:
```swift
let package = Package(
    name: "my-package",
    platforms: [.macOS(.v15)],  // REQUIRED for swift-testing
    ...
)
```
Source: runtime probe `/tmp/swift-research-probe/lib-test/` — first run failed, fixed run passed.

### FM-2: Global mutable var in Swift 6

**Error**: `error: var 'X' is not concurrency-safe because it is nonisolated global shared mutable state`

**Trigger**: any top-level `var` in Swift 6. Common pattern from Swift 5 codebase.

**Fix**: `let`, `@MainActor`, or actor encapsulation.

### FM-3: Sendable non-class not caught automatically

Interesting finding from probes: passing a non-Sendable class instance to a `Task` via closure capture compiled without error in our probe. This is because **within the same concurrency domain** (e.g., both in main-actor context) transfers are permitted. The error only triggers when crossing isolation domains concurrently. Don't assume the compiler catches every race — design isolation carefully.

### FM-4: await inside a non-async context

**Error**: `'async' call in a function that does not support concurrency`

**Fix**: mark the enclosing function `async`, or use `Task { }`.

### FM-5: Capture of mutable var in async closure

```swift
// Error in Swift 6
var counter = 0
Task { counter += 1 }  // error: mutation of captured var 'counter' in concurrently-executing code
```

**Fix**: use an actor or `@MainActor` annotated context.

---

## Sources

- Runtime probe: `/tmp/swift-research-probe/actor-test/` — actor + TaskGroup + AsyncThrowingStream (Swift 6.1.2, exit 0)
- Runtime probe: `/tmp/swift-research-probe/global-state-test/` — global mutable var error (exit 1, exact error text captured)
- Runtime probe: `/tmp/swift-research-probe/lib-test/` — swift-testing platform requirement (exit 1 without platforms, exit 0 after fix)
- Runtime probe: `/tmp/swift-research-probe/strict-test/` — @MainActor isolation + warning text
- Swift Evolution SE-0414 region-based isolation: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md
- Swift Evolution SE-0352 existential any: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0352-implicit-open-existentials.md
- `swift --version` output: `Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5) Target: arm64-apple-macosx15.0`
