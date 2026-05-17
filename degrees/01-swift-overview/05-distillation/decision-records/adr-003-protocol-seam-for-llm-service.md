# ADR-003: Each consumer defines its own `LLMService` protocol; AnthropicClient conforms via extension

**Date**: 2026-05-16

## Decision
Every consumer of the LLM (L3 CLI, L4 backend, L5 view model, L6 shared library, capstone) defines its own local `LLMService` protocol with exactly the methods it needs. `AnthropicClient` gets a one-line extension declaring conformance in each consumer's module. Tests inject `MockLLMService`.

## Alternatives considered
1. **Put `LLMService` in `AnthropicClient`** — single source of truth, every consumer imports it. Rejected: would force all consumers to share a single surface shape; the L3 CLI needs `stream(_:)` only, the L4 backend needs `send(_:) + stream(_:)`, the capstone macOS app needs `stream(_:)`. Each consumer's needs differ slightly.
2. **No protocol, depend directly on `AnthropicClient`** — simplest. Rejected: makes mocking impossible (struct, can't subclass), and prevents the capstone's swap between `AnthropicClient` (direct) and `BackendLLMService` (proxy).
3. **One shared protocol package** — abstract the common base. Rejected: premature abstraction; the rule-of-three threshold isn't hit until the capstone, where in fact two different concretes implement the protocol (`AnthropicClient` and `BackendLLMService`).

## Why per-consumer local protocols
1. **Each consumer minimises its surface.** L3 only does streaming; its protocol is one method. L4 needs both shapes; its protocol is two methods. No consumer carries methods it doesn't use.
2. **Conformance is one line.** `extension AnthropicClient: LLMService {}` per consumer module. Zero structural cost in the client; consumers control their own contract.
3. **Capstone payoff.** When the capstone needed a `BackendLLMService` that forwards to a local Hummingbird proxy, it just had to conform to the same protocol — the view model swap is a constructor argument. No structural refactor.
4. **Region isolation.** Each consumer's protocol is `Sendable`, so the protocol-typed property `let service: any LLMService` is safe to cross actor boundaries.

## Trade-offs accepted
- **Some duplication.** The protocol declaration appears in 5 modules with very similar shape. Acceptable: the declarations are 3-15 lines each and the alternative (a shared package) would introduce a dependency that buys little.
- **No central registry of LLM service shapes.** If someone wants to know "what does an LLM service look like in this codebase?" they read the consumer they care about.

## Evidence
- POC: `L3-cli-chat/Sources/ChatCore/LLMService.swift:1-12` — stream-only protocol.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/LLMService.swift:1-17` — send + stream.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/LLMService.swift:1-10` — stream-only.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/LLMService.swift` — stream-only.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/BackendLLMService.swift:7-78` — second concrete; `LLMService` for the proxy.
- POC: `L-capstone-multiplatform-chat/Sources/ChatMacApp/ChatMacApp.swift:11-22` — runtime swap between `AnthropicClient` and `BackendLLMService`.
- See also: pattern `patterns/llm-service-protocol-seam.md`, anti-pattern `anti-patterns/coupling-chatcore-to-anthropic-types.md`.
