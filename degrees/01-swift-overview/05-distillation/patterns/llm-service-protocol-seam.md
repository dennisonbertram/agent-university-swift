# Pattern: `LLMService` protocol seam — `extension AnthropicClient: LLMService {}` keeps the cost zero

**Category**: pattern

## What
Every layer that consumes the LLM (CLI, HTTP service, view model, capstone backend client) defines a tiny local `LLMService` protocol with exactly the surface it needs (`stream(_:)`, sometimes `send(_:)`). Then a one-line extension declares `AnthropicClient: LLMService`. Each consumer pins on the abstraction and injects a mock in tests. The shape of the abstraction varies per consumer; the concrete client stays unchanged.

## When to apply
- Whenever you want to test a layer that orchestrates calls to a model without doing live HTTP.
- When you need to swap implementations: real Anthropic ↔ local proxy backend ↔ test mock. The capstone proves the value: macOS app talks to either `AnthropicClient` (direct) or `BackendLLMService` (proxy) through the same protocol.

## Canonical code

The protocol is defined where it is used, not where the client lives:

```swift
// In ChatCore (the shared library):
import AnthropicClient

public protocol LLMService: Sendable {
    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error>
}

extension AnthropicClient: LLMService {}
```

In the backend, the surface is wider:
```swift
// In ToolService / ChatBackendLib:
public protocol LLMService: Sendable {
    func send(_ request: MessageRequest) async throws -> Message
    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error>
}
extension AnthropicClient: LLMService {}
```

In the capstone macOS app, the *same* protocol has two real implementations:

```swift
@MainActor @Observable
public final class ChatViewModel { public let service: any LLMService }

// 1. Direct mode:
let vm = ChatViewModel(service: AnthropicClient(apiKey: key))

// 2. Proxy mode through the local backend:
let vm = ChatViewModel(service: BackendLLMService(baseURL: URL(string: "http://localhost:8080")!))
```

`BackendLLMService` is a separate struct that also conforms to `LLMService` and forwards through `URLSession`.

## Variants and trade-offs
- Each consumer redefines `LLMService` with the minimum surface they need (L3 and L5 use stream-only; L4 and capstone add `send`). This prevents the abstraction from leaking concerns the consumer does not care about.
- The protocol stays in the consumer's module — the concrete `AnthropicClient` does not depend on any consumer.
- An alternative would be to put `LLMService` in `AnthropicClient` itself. The corpus deliberately does not — see ADR `decision-records/adr-003-protocol-seam-for-llm-service.md`.

## Evidence
- POC: `L3-cli-chat/Sources/ChatCore/LLMService.swift:1-12` — stream-only protocol; `extension AnthropicClient: LLMService {}`.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/LLMService.swift:1-17` — `send` + `stream` protocol; same extension pattern.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/LLMService.swift:1-10` — repeats the pattern.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/LLMService.swift` — repeats.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/BackendLLMService.swift:7-78` — second concrete implementation conforming to the same protocol; lets the macOS app run in proxy mode.
- POC: `L-capstone-multiplatform-chat/Sources/ChatMacApp/ChatMacApp.swift:11-22` — runtime swap between direct and proxy via env var.
- See also: gotcha `gotchas/unchecked-sendable-needed-for-test-mocks.md`, ADR `decision-records/adr-003-protocol-seam-for-llm-service.md`, playbook `playbooks/playbook-end-to-end-test-llm-app.md`.
