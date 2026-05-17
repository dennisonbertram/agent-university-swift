# Before-you-build: Swift 6 concurrency task

Tick every box before writing code that crosses isolation boundaries (UI ↔ background work, actor ↔ task, etc.).

## Toolchain
- [ ] `swift --version` shows 6.1+. The corpus is verified on Swift 6.1.2.
- [ ] `Package.swift` has `swift-tools-version: 6.1` — Swift 6 language mode by default.
- [ ] `platforms:` is declared (avoids the `'isolation()' is only available in macOS 10.15 or newer` error).

## Type / state design
- [ ] Default to `struct` for model data. Use `class` only for identity, shared mutation, or framework interop.
- [ ] Mutable shared state lives in an `actor` or behind `@MainActor`. No top-level `var`.
- [ ] Types that cross task boundaries are `Sendable` (structs of `Sendable` fields → automatic; `final class` → must declare).
- [ ] Test mocks that hold mutable state use `@unchecked Sendable` plus `NSLock` (only if real cross-isolation access). See gotcha `gotchas/unchecked-sendable-needed-for-test-mocks.md`.

## Closures and tasks
- [ ] You snapshot `self` properties to local `let`s before any `@Sendable` closure (`AsyncThrowingStream { continuation in ... }` is `@Sendable`). See gotcha `gotchas/captured-let-snapshot-in-sendable-closure.md`.
- [ ] You prefer structured concurrency (`withThrowingTaskGroup`, `for try await ...`) over `Task { ... }` detachment.
- [ ] Cancellation is explicit: `try Task.checkCancellation()` in long loops, `continuation.onTermination = { _ in task.cancel() }` for streams.

## Existential types
- [ ] All protocol-as-type usages have the `any` keyword: `let service: any LLMService`, not `let service: LLMService`.

## Region-based isolation
- [ ] You do NOT pre-emptively `@unchecked Sendable`-mark every class. Region-based isolation (SE-0414) often makes the cross legal without an annotation; let the compiler tell you when it actually needs help.

## When you hit an error
- [ ] You consult `playbooks/playbook-debug-swift6-sendable-errors.md` — the canonical fix templates.

## Evidence
- Research: `01-research/01-language-and-concurrency.md` §9 lines 272-338 — Sendable, region-based isolation, escape hatches.
- Research: `01-research/01-language-and-concurrency.md` §11-§12 lines 388-460 — Swift 5 vs 6 differences, failure modes.
- Research: `01-research/06-expectation-gaps.md` EG-01 (warnings → errors), EG-10 (region-based isolation permissiveness).
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:51-55` — snapshot pattern.
- See also: gotcha `gotchas/swift6-global-mutable-state-is-error.md`, playbook `playbooks/playbook-debug-swift6-sendable-errors.md`.
