# Expectation Gaps — Where LLM Prior Models Are Wrong

This file documents every significant place where a code-generating LLM's training data is likely wrong, outdated, or misleading for this specific Swift stack. Each gap has evidence.

---

## EG-01: Swift 6 vs Swift 5 Concurrency — Warnings vs Errors

**Wrong assumption**: Sendable violations and global mutable state issues produce warnings in Swift 6, same as Swift 5.

**Reality**: In Swift 6 (tools-version 6.0+), concurrency violations are **compile errors** by default, not warnings. The strictness that was opt-in with `-enable-experimental-feature StrictConcurrency` in Swift 5 is now the default.

**Evidence** (runtime probe, exact error):
```
error: var 'globalMutableVar' is not concurrency-safe because it is 
nonisolated global shared mutable state
  note: convert 'globalMutableVar' to a 'let' constant
  note: add '@MainActor' to make part of global actor 'MainActor'
  note: disable concurrency-safety checks if accesses are protected
        by an external synchronization mechanism
```
Source: runtime probe `/tmp/swift-research-probe/global-state-test/` — exit code 1.

**Impact**: LLM-generated code that uses global mutable variables (common in Swift 5 examples) will fail to compile in Swift 6 Package.swift targets with `swift-tools-version: 6.1`.

**Fix**: `let` (immutable), `@MainActor` annotation, actor encapsulation, or `nonisolated(unsafe)` escape hatch.

---

## EG-02: swift package init Does NOT Add platforms Declaration

**Wrong assumption**: `swift package init --type executable` produces a production-ready Package.swift.

**Reality**: The generated Package.swift has no `platforms:` declaration. This causes swift-testing `@Test` to fail with `error: 'isolation()' is only available in macOS 10.15 or newer`.

**Evidence** (runtime probe):
```
// Generated Package.swift — no platforms:
// swift-tools-version: 6.1
let package = Package(
    name: "hello-spm",
    targets: [
        .executableTarget(name: "hello-spm"),
    ]
)
```

Then running `swift test` on a library package (also generated without platforms) produced:
```
error: 'isolation()' is only available in macOS 10.15 or newer
```
Source: runtime probe `/tmp/swift-research-probe/lib-test/` — first attempt, exit code 1.

**Fix**: Always add `platforms: [.macOS(.v15)]` (or appropriate) to every Package.swift.

---

## EG-03: Hummingbird 1.x vs 2.x API — Complete Incompatibility

**Wrong assumption**: Hummingbird routes are registered as `app.router.get(...)` and handlers receive `HBRequest`.

**Reality**: Hummingbird 2.x (current as of 2026) has an entirely different API. There is no `HBRequest`, no `HBApplication`, and no `HB` prefix on any type.

| LLM-generated (v1 pattern) | Correct (v2 pattern) |
|---------------------------|----------------------|
| `let app = HBApplication(configuration:)` | `let router = Router(); let app = Application(router:configuration:)` |
| `app.router.get("path") { req in ... }` | `router.get("path") { req, ctx in ... }` |
| `(HBRequest) -> EventLoopFuture<HBResponse>` | `(Request, Context) async throws -> ResponseType` |
| `HBMiddleware` protocol | `RouterMiddleware` protocol |

**Evidence**:
- GitHub: https://github.com/hummingbird-project/hummingbird — v2.23.0 README shows `Application(router: router)`
- Source: `Application.swift` — struct uses `Responder: HTTPResponder` not NIO futures
- Runtime probe: `Application(router: router, configuration: .init(address: .hostname(...)))` — Build complete!

**Impact**: All Hummingbird 1.x tutorials, Stack Overflow answers, and pre-2024 blog posts describe the wrong API.

---

## EG-04: @Observable vs ObservableObject — New Default in Swift 5.9+

**Wrong assumption**: SwiftUI view models use `ObservableObject` + `@Published` + `@StateObject`.

**Reality**: Since Swift 5.9 / Xcode 15 (2023), `@Observable` macro is the correct pattern. It's simpler, more performant, and the direction Apple is pushing.

| Old (ObservableObject) | New (@Observable) |
|------------------------|-------------------|
| `: ObservableObject` | `@Observable` |
| `@Published var x` | `var x` (just a stored prop) |
| `@StateObject var vm` | `@State var vm` |
| `@ObservedObject var vm` | `var vm: MyModel` |
| `@EnvironmentObject var vm` | `@Environment(MyModel.self) var vm` |
| `@Binding var x` | `@Bindable var vm; vm.$x` |

**Evidence**: Swift Evolution SE-0395 (`@Observable`): https://github.com/swiftlang/swift-evolution/blob/main/proposals/0395-observability.md — shipped in Swift 5.9, Xcode 15, macOS 14/iOS 17.

**Caveat**: `@Observable` requires macOS 14 / iOS 17. For deployment targets of macOS 13 or lower, fall back to `ObservableObject`. This POC stack targets macOS 15, so `@Observable` is correct.

---

## EG-05: Anthropic SSE Stream Does NOT End with data: [DONE]

**Wrong assumption**: Anthropic's streaming API, like OpenAI's, ends the SSE stream with `data: [DONE]`.

**Reality**: Anthropic uses `event: message_stop` / `data: {"type": "message_stop"}`. After this event, the HTTP connection closes naturally.

**Evidence** (from official docs, accessed 2026-05-16):
```
event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}}

event: message_stop
data: {"type":"message_stop"}

[connection closes]
```
Source: https://platform.claude.com/docs/en/api/messages-streaming

**Impact**: An SSE parser that checks `if data == "[DONE]"` will either:
1. Silently continue waiting after stream ends (hang)
2. Process `message_stop` as a parse error (crash)

**Fix**: check `if event.type == "message_stop" { continuation.finish(); return }`.

---

## EG-06: No Official Anthropic Swift SDK Exists

**Wrong assumption**: Anthropic has an official Swift SDK (similar to their Python `anthropic` package).

**Reality**: As of 2026-05, Anthropic's official SDKs are: Python, TypeScript/Node, Go, Java, PHP, Ruby. There is NO official Swift SDK.

**Evidence**:
- GitHub API `https://api.github.com/orgs/anthropics/repos` — only Swift repo is `anthropics/swift-markdown-ui` (a Markdown renderer, not an API client)
- Anthropic SDK listing: Python, TypeScript, PHP, Ruby, Go, Java — no Swift

**Impact**: Any agent that says "install the anthropic Swift package" is wrong. You must build the client yourself or use an unofficial community SDK.

**Community options** (all unofficial, pre-1.0, low-star):
- `fumito-ito/AnthropicSwiftSDK` 0.14.0 — most feature-complete
- `GeorgeLyon/SwiftClaude` — Swift 6 native, no tagged releases

---

## EG-07: SwiftUI Compiles with CLT Only (but Cannot Run)

**Wrong assumption**: SwiftUI requires full Xcode to even compile.

**Reality**: SwiftUI compiles successfully with the Command Line Tools (CLT) only on macOS 15. `import SwiftUI`, `@main struct App: App`, `WindowGroup`, `Text` all compile.

**Evidence** (runtime probe):
```bash
# CLT-only, no Xcode.app installed
swift build  # on a SwiftUI target
# Build complete! (34.67s) — exit 0
```
Source: runtime probe `/tmp/swift-research-probe/swiftui-test/`

**Caveat**: CLT builds cannot RUN the SwiftUI app (no app bundle signing/launching), cannot build iOS targets, and cannot generate previews. But `swift build` succeeds, which is useful for CI and type-checking.

---

## EG-08: swift-testing Is NOT a Package Dependency

**Wrong assumption**: To use swift-testing, add it to `Package.swift` dependencies like any other library.

**Reality**: swift-testing is bundled with the Swift 6 toolchain. `import Testing` works without any Package.swift dependency entry.

**Evidence**:
- GitHub: https://github.com/apple/swift-testing — README states "ships as part of the Swift 6 toolchain and Xcode 16"
- Runtime probe: library package with NO swift-testing dependency in Package.swift, but `import Testing` + `@Test` in test target → `swift test` passes, shows "Testing Library Version: 124.4"

Source: runtime probe `/tmp/swift-research-probe/lib-test/` — no dependency added, tests run successfully.

**Impact**: LLM-generated Package.swift that adds `.package(url: ".../swift-testing", from: "...")` is wrong — you'll get a redundant dependency or version conflict.

---

## EG-09: Hummingbird Application Needs buildResponder() or Router

**Wrong assumption**: `Application` takes a `Router` directly as a single argument.

**Reality**: `Application` has two init forms:
1. `Application(responder: myRouter.buildResponder(), ...)` — explicit builder call
2. `Application(router: myRouter, ...)` — convenience that calls `buildResponder()` internally

Both are valid. The confusing form in some docs shows `Application(router: ...)` — this works because there's a generic `init<ResponderBuilder: HTTPResponderBuilder>(router:)` convenience init.

**Evidence**: Source `Application.swift` lines 243-271 — both inits exist and compile.

**Impact**: LLM code that does `Application(router: router)` is correct. But `Application(router: router.buildResponder())` is also correct (redundant call, not an error). `Application(myRouter)` without a label will fail.

---

## EG-10: Actor Crossing and Sendable — Not All Non-Sendable Types Cause Errors

**Wrong assumption**: Any non-`Sendable` type that touches any async/await code is a Swift 6 compile error.

**Reality**: Swift 6's region-based isolation (SE-0414) allows transferring non-Sendable values across isolation domains when the compiler can prove the source region no longer has access. This is more permissive than "all crossing types must be Sendable."

Additionally, passing a non-Sendable class to an actor function compiles without error in some cases — specifically when the value doesn't escape and the actor call is the terminal use.

**Evidence** (runtime probe):
```swift
class NonSendable { var x: Int = 0 }
actor MyActor {
    func doWork(_ ns: NonSendable) { ns.x = 1 }
}
// await actor.doWork(obj)  — compiles without error in Swift 6.1.2
```
Source: runtime probe `/tmp/swift-research-probe/sendable-test2/` — exit 0, no errors.

**Impact**: LLM agents should not add unnecessary `@unchecked Sendable` conformances "just in case." The compiler will tell you when you actually need to fix a crossing; don't pre-emptively mark everything Sendable.

---

## EG-11: AsyncParsableCommand vs ParsableCommand for Async Entry Points

**Wrong assumption**: Use `@main struct App: AsyncParsableCommand` for any async CLI tool.

**Reality**: `AsyncParsableCommand` is correct. But `ParsableCommand` cannot have an `async func run()` — it must be synchronous. The distinction matters for L3's CLI chat tool which needs async API calls.

**Evidence**: swift-argument-parser 1.7.1 — `AsyncParsableCommand` requires conformance to make `run()` async. Runtime probe `/tmp/swift-research-probe/argparse-test/` uses `AsyncParsableCommand` and compiles successfully.

**Additional nuance**: `@main AsyncParsableCommand` creates a top-level `Task` internally and runs the async work. This is compatible with structured concurrency.

---

## EG-12: max_tokens Is Required by Anthropic API

**Wrong assumption**: `max_tokens` is optional in the Anthropic Messages API (it's optional in some other LLM APIs).

**Reality**: `max_tokens` is a **required** field. Omitting it causes a 400 Bad Request error.

**Evidence**: https://platform.claude.com/docs/en/api/messages — table shows `max_tokens` as required (✅).

**Impact**: LLM-generated Swift structs that make `maxTokens` optional with `?` will produce runtime 400 errors.

---

## EG-13: SSE ping Events Must Be Handled

**Wrong assumption**: Anthropic's SSE stream only sends data events.

**Reality**: The stream includes `ping` events dispersed throughout. Parsers that don't handle `ping` will crash when trying to decode `{"type":"ping"}` as a content event.

**Evidence**: https://platform.claude.com/docs/en/api/messages-streaming:
```
event: ping
data: {"type": "ping"}
```
These appear between content_block_delta events.

**Fix**:
```swift
if eventType == "ping" { continue }
```

---

## EG-14: Middleware Order Is Not Global in Hummingbird 2

**Wrong assumption**: Adding middleware to a Hummingbird router applies it to all routes.

**Reality**: In Hummingbird 2, `router.middlewares.add()` only applies to routes registered **after** the call. Routes registered before are not affected.

**Evidence**: Source `Application.swift` doc comment: "Middleware is applied only to endpoints registered after the `add(middleware:)` call."

---

## EG-15: swift-testing Runs Tests in Parallel by Default

**Wrong assumption**: Tests run sequentially (XCTest behavior).

**Reality**: swift-testing runs tests in parallel by default. Tests with shared mutable state will race.

**Evidence**: Runtime probe output shows tests starting and completing non-sequentially:
```
◇ Test "Async test" started.
◇ Test isPositive(n:) started.
◇ Test "Subtraction works" started.
✔ Test "Async test" passed after 0.001 seconds.
✔ Test "Subtraction works" passed after 0.001 seconds.
```
(Multiple tests started before any completed)

**Fix for sequential tests**: use `@Test(.serialized)` or group in a `@Suite(.serialized)`.

---

## Sources

All evidence citations are inline per gap above. Key sources:

- Runtime probes: `/tmp/swift-research-probe/` directory — all exit codes captured
- https://platform.claude.com/docs/en/api/messages-streaming — SSE format
- https://platform.claude.com/docs/en/api/messages — required fields
- https://github.com/hummingbird-project/hummingbird — v2.23.0 source
- https://github.com/apple/swift-testing — bundled with Swift 6 toolchain
- https://github.com/apple/swift-argument-parser — v1.7.1
- Swift Evolution SE-0395: @Observable
- Swift Evolution SE-0414: region-based isolation
