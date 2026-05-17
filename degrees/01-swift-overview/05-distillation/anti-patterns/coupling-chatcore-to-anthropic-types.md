# Anti-pattern: making `ChatCore` (or any consumer) depend on `AnthropicClient` directly without a protocol seam

**Category**: anti-pattern

## Broken approach
The view model or chat session holds a concrete `AnthropicClient`:

```swift
// DO NOT do this — couples logic to a specific vendor
@MainActor @Observable
public final class ChatViewModel {
    public let client: AnthropicClient                  // ← concrete dependency
    public func send(userText: String) async {
        for try await event in client.stream(req) { /* ... */ }
    }
}
```

## Why it fails
- Tests cannot inject a mock without subclassing `AnthropicClient` (which is a struct, so subclassing isn't possible) or rebuilding the entire HTTP transport mock from scratch.
- The capstone needs the view model to talk to either `AnthropicClient` (direct mode) or `BackendLLMService` (proxy through Hummingbird). With a concrete dependency, this is a structural change — with a protocol, it's a constructor argument.
- New consumers (CLI, server, view model) each have to know about Anthropic types specifically. The blast radius of any change to `AnthropicClient`'s public API spreads everywhere.

## Right approach
Define an `LLMService` protocol with exactly the surface the consumer needs. The consumer depends on the protocol; `AnthropicClient` gets a one-line extension conforming to it.

```swift
public protocol LLMService: Sendable {
    func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error>
}

extension AnthropicClient: LLMService {}

@MainActor @Observable
public final class ChatViewModel {
    public let service: any LLMService                  // ← protocol seam
    public init(service: any LLMService, ...) { self.service = service }
}
```

This is the same pattern that lets `BackendLLMService: LLMService` plug in transparently:

```swift
public struct BackendLLMService: LLMService {
    public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        // talks to /chat/stream via URLSession
    }
}

let vm = ChatViewModel(service: BackendLLMService(baseURL: URL(string: "http://localhost:8080")!))
```

## Evidence
- POC: `L3-cli-chat/Sources/ChatCore/LLMService.swift:1-12` — protocol introduced at L3.
- POC: `L4-hummingbird-tool-service/Sources/ToolService/LLMService.swift:1-17` — protocol redefined locally.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/LLMService.swift:1-10` — same.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/BackendLLMService.swift:7` — second concrete implementation of the same protocol; lets the macOS app switch implementations at runtime via env var.
- POC: `L-capstone-multiplatform-chat/Sources/ChatMacApp/ChatMacApp.swift:11-22` — runtime switch between `AnthropicClient` and `BackendLLMService`.
- See also: pattern `patterns/llm-service-protocol-seam.md`, ADR `decision-records/adr-003-protocol-seam-for-llm-service.md`.
