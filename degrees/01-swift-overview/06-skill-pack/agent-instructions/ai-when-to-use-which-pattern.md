# When to Use Which Pattern

[Back to index](../index.md) | Related: [ai-system-prompt-swift.md](ai-system-prompt-swift.md)

Decision trees for the choices that come up repeatedly. Pick the branch that matches your situation.

---

## Shared mutable state across concurrency boundaries

```
Need to share mutable state?
├─ Accessed from a single actor or @MainActor context?
│   └─ Use a property on an actor or @MainActor class
├─ Accessed from multiple actors / tasks?
│   ├─ Value type with Sendable conformance?
│   │   └─ Pass by value (copy) — struct, enum, or tuple
│   └─ Reference type?
│       ├─ Serialise access needed?
│       │   └─ Use actor { var state; func get/set }
│       └─ All-UI, main-thread only?
│           └─ Use @MainActor final class
└─ Test mock that needs to be Sendable?
    ├─ Single task accesses it?
    │   └─ @unchecked Sendable with a comment
    └─ Multiple tasks access it?
        └─ @unchecked Sendable + NSLock for all var access
```

See: [lesson-02](../lessons/lesson-02-swift6-concurrency.md), [ref-swift6-concurrency-keywords](../reference/ref-swift6-concurrency-keywords.md)

---

## Passing data into an async closure

```
Need a value from outer scope inside an AsyncThrowingStream closure?
├─ Value is already let (immutable)?
│   └─ Capture directly — it's Sendable by definition
└─ Value is var (mutable)?
    └─ Take a let snapshot before the closure:
       let frozen = mutableProperty
       AsyncThrowingStream { cont in
           Task { use(frozen) }
       }
```

NEVER capture `self` when `self` is mutable and the closure crosses an actor boundary. Capture `self` explicitly only when `self` is `@MainActor` or `actor`-isolated and the task respects that isolation.

See: [recipe-streaming-sse-consumer](../recipes/recipe-streaming-sse-consumer.md), [lesson-02](../lessons/lesson-02-swift6-concurrency.md)

---

## HTTP layer testability

```
Need to make HTTP calls that tests can intercept?
├─ Using URLSession.dataTask / .bytes directly?
│   └─ STOP — this is not mockable
└─ Define protocol HTTPTransport: Sendable
    ├─ Production: URLSessionTransport implements it via URLSession
    └─ Tests: MockHTTPTransport returns canned Data / AsyncThrowingStream<UInt8>
```

Never inject `URLSession` directly. Always inject `any HTTPTransport`.

See: [lesson-04](../lessons/lesson-04-http-transport-seam.md), [recipe-anthropic-client-init](../recipes/recipe-anthropic-client-init.md)

---

## LLM service testability

```
Need to test code that calls the LLM?
└─ Define protocol LLMService: Sendable
    ├─ Production: extension AnthropicClient: LLMService {}
    └─ Tests: MockLLMService with canned events
        ├─ Simple (single task): @unchecked Sendable, plain stored properties
        └─ Multi-task (integration test): @unchecked Sendable + NSLock
```

See: [recipe-mock-llm-service-for-tests](../recipes/recipe-mock-llm-service-for-tests.md), [lesson-12](../lessons/lesson-12-test-driven-development-in-swift.md)

---

## Streaming response to a caller

```
Need to stream output from an async operation?
├─ Caller is Swift (in-process)?
│   └─ Return AsyncThrowingStream<OutputType, Error>
│       └─ Attach continuation.onTermination = { _ in task.cancel() }
└─ Caller is HTTP client (over network)?
    └─ Hummingbird ResponseBody with writer.write() per chunk
        └─ Terminate on all paths: success, error, and cancellation
```

See: [recipe-hummingbird-sse-response](../recipes/recipe-hummingbird-sse-response.md), [lesson-04](../lessons/lesson-04-http-transport-seam.md)

---

## Codable with snake_case fields

```
Need to decode JSON with snake_case field names?
├─ Tempted to use .convertFromSnakeCase?
│   └─ STOP — if any type has explicit CodingKeys, this double-transforms them
└─ Use explicit CodingKeys enum in every type:
   enum CodingKeys: String, CodingKey {
       case maxTokens = "max_tokens"
       case stopReason = "stop_reason"
   }
```

See: [ts-keynotfound-during-codable-decode](../troubleshooting/ts-keynotfound-during-codable-decode.md), [lesson-03](../lessons/lesson-03-typed-clients-with-codable.md)

---

## View model for SwiftUI

```
Writing a view model?
├─ New code (Swift 5.9+)?
│   └─ @MainActor @Observable final class MyVM {
│          var state = ""       ← plain var, not @Published
│      }
│      // In view: @State private var vm = MyVM()
└─ Migrating from ObservableObject?
    ├─ class MyVM: ObservableObject → @Observable final class MyVM
    ├─ @Published var x → var x
    ├─ @StateObject var vm → @State private var vm
    └─ @ObservedObject var vm → @Bindable var vm (for two-way binding in child views)
```

See: [lesson-08](../lessons/lesson-08-swiftui-macos-app.md), [recipe-swiftui-streaming-text](../recipes/recipe-swiftui-streaming-text.md)

---

## Multiplatform package layout

```
Building a package that runs on both iOS and macOS?
├─ Shared business logic → library target
├─ Shared SwiftUI views → second library target (import Observation, not SwiftUI in VM)
├─ macOS app entry point → separate executable target in Sources/
├─ iOS app entry point → separate directory (e.g., iosApp/) NOT a SwiftPM target
└─ Package.swift platforms: [.macOS(.v14), .iOS(.v17)]
```

Platform guards: always at modifier level, not around entire bodies.

See: [lesson-09](../lessons/lesson-09-multiplatform-swift-packages.md), [recipe-multiplatform-package-swift](../recipes/recipe-multiplatform-package-swift.md)

---

## Error recovery in a streaming LLM response

```
Streaming response updates a buffer when an error occurs?
└─ Use the three-branch pattern:
   var assistantStarted = false
   do {
       for try await chunk in stream {
           assistantStarted = true
           buffer += chunk
       }
   } catch is CancellationError {
       if assistantStarted { markCurrentMessageFailed() }
       else { removeCurrentPlaceholder() }
   } catch {
       if assistantStarted { markCurrentMessageFailed() }
       else { removeCurrentPlaceholder() }
       throw error
   }
```

See: [recipe-error-rollback-state-machine](../recipes/recipe-error-rollback-state-machine.md), [lesson-08](../lessons/lesson-08-swiftui-macos-app.md)

---

## Testing with TDD

```
Writing new functionality?
└─ Red → Green → Refactor → Regression
   1. Write a failing test first (#expect fails as expected)
   2. Write minimal code to make it pass
   3. Refactor if needed — keep tests green
   4. Pin the source file + line in a RegressionTests.swift comment
      so a future revert of that file is immediately visible
```

See: [lesson-12](../lessons/lesson-12-test-driven-development-in-swift.md), [recipe-red-green-regression-commits](../recipes/recipe-red-green-regression-commits.md)

---

Evidence: all decision branches trace to `05-distillation/patterns/`, `05-distillation/decision-records/`, and `05-distillation/gotchas/`.
