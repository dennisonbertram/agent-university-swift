# Pre-flight Checklist — Before Writing Any Swift Code

[Back to index](../index.md) | Related: [ai-system-prompt-swift.md](ai-system-prompt-swift.md)

Run through this list before writing the first line of Swift for any task.

---

## Package structure

- [ ] `Package.swift` declares `swift-tools-version: 6.1` at the top
- [ ] `platforms:` is declared immediately after the package name — e.g. `.macOS(.v14)` — never omitted
- [ ] Business logic is in a `.library` target, not the `.executableTarget`
- [ ] The executable target is a thin shim that calls the library
- [ ] There is a `.testTarget` that depends on the library target
- [ ] `swift package init` output was followed by adding `platforms:` before anything else

## Swift 6 strict concurrency

- [ ] No global `var` — use `let`, `actor`, `@MainActor` class, or `nonisolated(unsafe)` with a documented lock
- [ ] Protocol-typed stored properties use `any`: `let service: any MyProtocol`
- [ ] Types passed across actor boundaries conform to `Sendable`
- [ ] Structs: if all stored properties are `Sendable`, conformance is auto-synthesized — just add `: Sendable`
- [ ] Classes: must be `final` and declare `: Sendable` explicitly; all stored properties must be immutable or `Sendable`
- [ ] `@unchecked Sendable` is used only for test mocks with documented single-thread or `NSLock` guarantee
- [ ] Closures that escape actor isolation capture only `let` snapshots — no `var` capture

## Testing

- [ ] Tests use `import Testing`, `@Test`, `#expect`, `#require` — NOT `import XCTest`
- [ ] Test file is in a `.testTarget` with `platforms:` declared (inherited from Package.swift)
- [ ] `@Suite` is used when grouping related tests
- [ ] Tests for `@MainActor`-isolated types annotate the entire suite `@MainActor`
- [ ] Mock types that are `@unchecked Sendable` are documented with the locking/isolation guarantee

## Codable

- [ ] NOT using `jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase` on any decoder that also decodes types with explicit `CodingKeys` — this double-transforms and breaks decoding
- [ ] Snake-case fields use explicit `CodingKeys` enum with the exact raw string value
- [ ] `max_tokens` / `maxTokens` uses an explicit `CodingKey` of `"max_tokens"`

## Dependency injection

- [ ] HTTP is injected via a `protocol HTTPTransport: Sendable` — not called directly through `URLSession`
- [ ] LLM logic is injected via a `protocol LLMService: Sendable` — not hardcoded to `AnthropicClient`
- [ ] Test doubles conform to the same protocol as production code

## AsyncThrowingStream

- [ ] Every `AsyncThrowingStream` producer attaches `continuation.onTermination = { _ in task.cancel() }`
- [ ] The `Task` that produces values is captured in a `let` before the closure
- [ ] `let` snapshots of mutable values are taken before entering the closure: `let frozen = mutableProp`

## Error handling

- [ ] Errors thrown from `async throws` functions are typed where possible (not `Error`)
- [ ] The rollback state machine (`assistantStarted` flag) is used when streaming to a mutable buffer

## Before running `swift test`

- [ ] `swift build` succeeds first
- [ ] If multiplatform: also built for the non-default target with `xcodebuild` or the second scheme
- [ ] No `// TODO` or `fatalError("not implemented")` left in non-test code paths that tests exercise

---

See also: [ai-checklist-before-writing-anthropic-integration.md](ai-checklist-before-writing-anthropic-integration.md), [ai-checklist-before-writing-swiftui-app.md](ai-checklist-before-writing-swiftui-app.md)

Evidence: `05-distillation/gotchas/`, `05-distillation/before-you-build/`, `05-distillation/patterns/`.
