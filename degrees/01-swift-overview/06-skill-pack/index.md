# Swift 6.1 Skill Pack — Autonomous Agent Edition

## Welcome

This skill pack teaches an LLM coding agent how to build a full-stack Swift product using Swift 6.1: a typed Anthropic API client, a streaming CLI chat tool, a Hummingbird HTTP service, and SwiftUI apps for macOS and iOS. Every lesson, recipe, and troubleshooting entry is grounded in the seven POCs (L1–L6 + capstone) and the 64-file distillation corpus produced during the Swift Overview degree. A reader who works through this pack end-to-end can produce production-quality Swift 6 code without reading the raw POC source.

---

## Quickstart

Get something running in 10 minutes: [quickstart.md](quickstart.md)

---

## Lessons — Sequential Learning Path

| # | File | What you learn |
|---|------|----------------|
| 1 | [lesson-01-swift-toolchain-and-swiftpm.md](lessons/lesson-01-swift-toolchain-and-swiftpm.md) | Verify Swift 6.1, init a package, add `platforms:`, run a passing swift-testing test |
| 2 | [lesson-02-swift6-concurrency.md](lessons/lesson-02-swift6-concurrency.md) | Strict concurrency, Sendable, `@MainActor`, actors, `AsyncThrowingStream` |
| 3 | [lesson-03-typed-clients-with-codable.md](lessons/lesson-03-typed-clients-with-codable.md) | Codable models, explicit `CodingKeys` for snake_case, JSON round-trip testing |
| 4 | [lesson-04-http-transport-seam.md](lessons/lesson-04-http-transport-seam.md) | Protocol-based DI for HTTP: `HTTPTransport`, `URLSessionTransport`, `MockHTTPTransport` |
| 5 | [lesson-05-anthropic-messages-api-streaming.md](lessons/lesson-05-anthropic-messages-api-streaming.md) | Request shape, SSE format, ping filtering, `message_stop` termination |
| 6 | [lesson-06-cli-tools-with-argument-parser.md](lessons/lesson-06-cli-tools-with-argument-parser.md) | `AsyncParsableCommand`, options/flags, multi-turn actor-backed conversation |
| 7 | [lesson-07-hummingbird-http-services.md](lessons/lesson-07-hummingbird-http-services.md) | Router, middleware ordering, JSON handlers, `ResponseBody` SSE streaming, in-process testing |
| 8 | [lesson-08-swiftui-macos-app.md](lessons/lesson-08-swiftui-macos-app.md) | `@main App`, `WindowGroup`, `@Observable` view model, `@Bindable` bindings, `@MainActor` isolation |
| 9 | [lesson-09-multiplatform-swift-packages.md](lessons/lesson-09-multiplatform-swift-packages.md) | `platforms: [.iOS(.v17), .macOS(.v14)]`, cross-platform SwiftUI subset, `#if os()` guards |
| 10 | [lesson-10-end-to-end-integration-testing.md](lessons/lesson-10-end-to-end-integration-testing.md) | View model ↔ live Hummingbird backend ↔ mocked upstream, `withLiveBackendForURLSession` |
| 11 | [lesson-11-dockerizing-a-swift-server.md](lessons/lesson-11-dockerizing-a-swift-server.md) | Multi-stage Dockerfile, `--static-swift-stdlib`, sibling-dep caveat, image size |
| 12 | [lesson-12-test-driven-development-in-swift.md](lessons/lesson-12-test-driven-development-in-swift.md) | Red/green/regression commit trail, swift-testing patterns, mock factories |

---

## Labs — Hands-On Exercises

| # | File | Outcome |
|---|------|---------|
| 1 | [lab-01-hello-spm.md](labs/lab-01-hello-spm.md) | Build and test a SwiftPM library from scratch |
| 2 | [lab-02-typed-codable-roundtrip.md](labs/lab-02-typed-codable-roundtrip.md) | Write a `User` Codable with explicit snake_case keys and round-trip test it |
| 3 | [lab-03-protocol-injected-http-mock.md](labs/lab-03-protocol-injected-http-mock.md) | Implement the HTTPTransport pattern in miniature |
| 4 | [lab-04-streaming-counter.md](labs/lab-04-streaming-counter.md) | Build an `AsyncThrowingStream<Int, Error>` with cancellation |
| 5 | [lab-05-cli-argparser-todo.md](labs/lab-05-cli-argparser-todo.md) | Build a `todo add|list|done` CLI with `AsyncParsableCommand` |
| 6 | [lab-06-hummingbird-echo.md](labs/lab-06-hummingbird-echo.md) | Hummingbird server with `POST /echo` that JSON-decodes and echoes the body |
| 7 | [lab-07-swiftui-counter.md](labs/lab-07-swiftui-counter.md) | SwiftUI macOS app with `@Observable` counter view model |
| 8 | [lab-08-multiplatform-greeter.md](labs/lab-08-multiplatform-greeter.md) | SwiftPM package targeting iOS+macOS with a shared SwiftUI greeting view |

---

## Recipes — Copy-Paste Solutions

| File | Task |
|------|------|
| [recipe-anthropic-client-init.md](recipes/recipe-anthropic-client-init.md) | Bootstrap `AnthropicClient` with all required headers |
| [recipe-streaming-sse-consumer.md](recipes/recipe-streaming-sse-consumer.md) | SSE byte-stream → typed event loop |
| [recipe-actor-conversation-history.md](recipes/recipe-actor-conversation-history.md) | `ConversationActor` with snapshot reads |
| [recipe-error-rollback-state-machine.md](recipes/recipe-error-rollback-state-machine.md) | Three-branch catch: cancel / partial / hard error |
| [recipe-hummingbird-sse-response.md](recipes/recipe-hummingbird-sse-response.md) | `ResponseBody { writer in ... }` SSE route |
| [recipe-swiftui-streaming-text.md](recipes/recipe-swiftui-streaming-text.md) | `@MainActor @Observable` view model + `@Bindable` view |
| [recipe-multiplatform-package-swift.md](recipes/recipe-multiplatform-package-swift.md) | `Package.swift` for iOS+macOS with library + executables |
| [recipe-mock-llm-service-for-tests.md](recipes/recipe-mock-llm-service-for-tests.md) | `MockLLMService` with canned events and captured requests |
| [recipe-red-green-regression-commits.md](recipes/recipe-red-green-regression-commits.md) | TDD commit trail and `RegressionTests.swift` template |
| [recipe-dockerfile-swift-server.md](recipes/recipe-dockerfile-swift-server.md) | Multi-stage Dockerfile for a Hummingbird backend |

---

## Troubleshooting — Symptom → Diagnosis → Fix

| File | Symptom |
|------|---------|
| [ts-swift-test-fails-without-platforms.md](troubleshooting/ts-swift-test-fails-without-platforms.md) | `'isolation()' is only available in macOS 10.15 or newer` |
| [ts-nonisolated-global-shared-mutable-state.md](troubleshooting/ts-nonisolated-global-shared-mutable-state.md) | `var 'X' is not concurrency-safe` |
| [ts-sendable-type-cannot-be-marshalled.md](troubleshooting/ts-sendable-type-cannot-be-marshalled.md) | Capture of non-Sendable / mutable var in concurrent closure |
| [ts-keynotfound-during-codable-decode.md](troubleshooting/ts-keynotfound-during-codable-decode.md) | `Key not found: "maxTokens"` with `convertFromSnakeCase` |
| [ts-anthropic-401-unauthorized.md](troubleshooting/ts-anthropic-401-unauthorized.md) | HTTP 401 from Anthropic |
| [ts-anthropic-429-rate-limited.md](troubleshooting/ts-anthropic-429-rate-limited.md) | HTTP 429 rate-limit and `Retry-After` handling |
| [ts-sse-stream-hangs-no-done-marker.md](troubleshooting/ts-sse-stream-hangs-no-done-marker.md) | Stream hangs waiting for `data: [DONE]` that never arrives |
| [ts-hummingbird-route-returns-404.md](troubleshooting/ts-hummingbird-route-returns-404.md) | Route registered but always returns 404 |
| [ts-hummingbird-middleware-not-applied.md](troubleshooting/ts-hummingbird-middleware-not-applied.md) | Middleware ignores a route |
| [ts-urlsession-bytes-cannot-be-mocked.md](troubleshooting/ts-urlsession-bytes-cannot-be-mocked.md) | `URLSession.AsyncBytes initializer is inaccessible` |
| [ts-swiftui-macos-window-does-not-open.md](troubleshooting/ts-swiftui-macos-window-does-not-open.md) | `swift run` produces no window |
| [ts-multiplatform-package-fails-ios-only-api.md](troubleshooting/ts-multiplatform-package-fails-ios-only-api.md) | `import AppKit` / `import UIKit` breaks cross-platform build |
| [ts-async-task-leaks-after-view-disappears.md](troubleshooting/ts-async-task-leaks-after-view-disappears.md) | Background task keeps running after view is gone |
| [ts-stream-true-flag-missing-from-request.md](troubleshooting/ts-stream-true-flag-missing-from-request.md) | SSE route returns a single block instead of a stream |
| [ts-hummingbird-1x-types-in-2x-project.md](troubleshooting/ts-hummingbird-1x-types-in-2x-project.md) | `cannot find 'HBApplication' in scope` |

---

## Reference — API Cheat Sheets and Version Pins

| File | Contents |
|------|----------|
| [ref-version-pins.md](reference/ref-version-pins.md) | Pinned versions: Swift 6.1.2, Hummingbird 2.x, swift-argument-parser 1.5+, Anthropic API |
| [ref-anthropic-messages-api.md](reference/ref-anthropic-messages-api.md) | Request/response shape, required headers, error codes |
| [ref-hummingbird-router-cheatsheet.md](reference/ref-hummingbird-router-cheatsheet.md) | Common router operations, middleware, testing |
| [ref-swift-testing-cheatsheet.md](reference/ref-swift-testing-cheatsheet.md) | `@Test`, `#expect`, `#require`, `@Suite`, parameterized tests |
| [ref-swift-argument-parser-cheatsheet.md](reference/ref-swift-argument-parser-cheatsheet.md) | `AsyncParsableCommand`, `@Option`, `@Argument`, `@Flag` |
| [ref-swiftui-cross-platform-modifiers.md](reference/ref-swiftui-cross-platform-modifiers.md) | Which modifiers work on both platforms; which need `#if os()` guards |
| [ref-swift6-concurrency-keywords.md](reference/ref-swift6-concurrency-keywords.md) | `Sendable`, `@MainActor`, `actor`, `nonisolated`, `@unchecked Sendable` |

---

## Examples — Annotated Real POC Code

| File | POC |
|------|-----|
| [example-l1-greeter.md](examples/example-l1-greeter.md) | L1: `Greeter.swift` + swift-testing tests |
| [example-l2-sseparser.md](examples/example-l2-sseparser.md) | L2: `StreamEvent.swift` SSE parser walkthrough |
| [example-l3-chatsession.md](examples/example-l3-chatsession.md) | L3: `ChatSession.send` with rollback logic |
| [example-l4-router.md](examples/example-l4-router.md) | L4: Hummingbird router with SSE `ResponseBody` |
| [example-l5-chatviewmodel.md](examples/example-l5-chatviewmodel.md) | L5: `ChatViewModel` — `@MainActor @Observable` |
| [example-l6-multiplatform-package-swift.md](examples/example-l6-multiplatform-package-swift.md) | L6: `Package.swift` with iOS+macOS targets |
| [example-capstone-end-to-end-test.md](examples/example-capstone-end-to-end-test.md) | Capstone: `EndToEndTests` with live Hummingbird backend |

---

## Assessments — Self-Check Exercises

| File | Topic |
|------|-------|
| [assessment-01-swiftpm-and-toolchain.md](assessments/assessment-01-swiftpm-and-toolchain.md) | SwiftPM, `platforms:`, swift-testing |
| [assessment-02-swift6-concurrency.md](assessments/assessment-02-swift6-concurrency.md) | Strict concurrency, Sendable, actors |
| [assessment-03-anthropic-api.md](assessments/assessment-03-anthropic-api.md) | Messages API, SSE, error mapping |
| [assessment-04-hummingbird.md](assessments/assessment-04-hummingbird.md) | Routing, middleware, streaming responses |
| [assessment-05-swiftui-multiplatform.md](assessments/assessment-05-swiftui-multiplatform.md) | `@Observable`, `@Bindable`, `#if os()` guards |

---

## Agent Instructions — Load Before Doing Swift Work

| File | Purpose |
|------|---------|
| [ai-system-prompt-swift.md](agent-instructions/ai-system-prompt-swift.md) | System-prompt context to prepend before any Swift task |
| [ai-checklist-before-writing-swift.md](agent-instructions/ai-checklist-before-writing-swift.md) | Pre-flight: toolchain, `platforms:`, test target, repo |
| [ai-checklist-before-writing-anthropic-integration.md](agent-instructions/ai-checklist-before-writing-anthropic-integration.md) | Pre-flight for Anthropic API integration |
| [ai-checklist-before-writing-swiftui-app.md](agent-instructions/ai-checklist-before-writing-swiftui-app.md) | Pre-flight for SwiftUI tasks |
| [ai-debugging-workflow.md](agent-instructions/ai-debugging-workflow.md) | When a Swift error appears: canonical lookup order |
| [ai-when-to-use-which-pattern.md](agent-instructions/ai-when-to-use-which-pattern.md) | Decision tree: testable HTTP, shared state, cross-platform |

---

## Provenance

**Research corpus:** `degrees/01-swift-overview/01-research/` — covers language/concurrency, SwiftPM, Anthropic API, Hummingbird, and SwiftUI multiplatform.

**POCs built during this degree:**

| POC | Description |
|-----|-------------|
| `L1-hello-spm` | Minimal SwiftPM library + executable with swift-testing; establishes the baseline package shape |
| `L2-anthropic-client` | Typed Anthropic Messages API client: `AnthropicClient`, `SSEParser`, `HTTPTransport` seam, 33 tests |
| `L3-cli-chat` | Multi-turn CLI chat: `ConversationActor`, `ChatSession` with rollback, `AsyncParsableCommand` |
| `L4-hummingbird-tool-service` | Hummingbird 2.x HTTP service: `GET /health`, `POST /chat`, `POST /chat/stream` with `MockLLMService` |
| `L5-swiftui-macos-app` | SwiftUI macOS chat app: `@MainActor @Observable ChatViewModel`, streaming deltas, cancellation |
| `L6-swiftui-ios-app` | Multiplatform SwiftPM package (iOS 17 + macOS 14) with shared views and `#if os()` guards |
| `L-capstone-multiplatform-chat` | Capstone unifying all layers: backend + macOS app + iOS shell + end-to-end tests |
