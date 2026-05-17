# Recipe — Red/Green/Regression Commit Trail

[Back to index](../index.md) | See also: [lesson-12-test-driven-development-in-swift.md](../lessons/lesson-12-test-driven-development-in-swift.md) | Pattern: `patterns/red-green-regression-tdd-trail.md`

## Use this when

You are implementing a new feature and want to maintain a clear audit trail.

## The three-commit pattern

```bash
# 1. Red — introduce failing test
git add Tests/MyTests/MyTests.swift
git commit -m "red: BT-004 error before delta rolls back user message"

# 2. Green — minimum implementation to pass
git add Sources/MyLib/ChatSession.swift
git commit -m "green: BT-004 rollback user message on error before any delta"

# 3. Regression — pin the specific behaviour
git add Tests/MyTests/RegressionTests.swift
git commit -m "regression: REGRESSION-001 system prompt forwarded in every request"
```

## `RegressionTests.swift` template

```swift
import Testing
@testable import MyModule

// This file pins specific observable behaviours identified during the green commit.
// If a test here fails, it means a refactor broke something that was previously verified.

@Suite("Regression Tests")
struct RegressionTests {

    // REGRESSION-001: system prompt must be forwarded in every request.
    // Green commit: 2026-05-16 — verified in L3 ChatSession.
    @Test("REGRESSION-001: system prompt is forwarded in every request")
    func systemPromptForwarded() async throws {
        let mock = MockLLMService()
        mock.events = [.messageStop]
        let session = ChatSession(service: mock, model: "m", maxTokens: 100,
                                  system: "Be brief")
        _ = try? await { for try await _ in session.send(userText: "hi") {} }()
        let req = mock.capturedRequests[0]
        #expect(req.system == "Be brief",
                "System prompt must be forwarded; if nil, it was lost during refactor")
    }

    // REGRESSION-002: stream flag must be set on every streaming request.
    // Green commit: 2026-05-16 — verified in L3 ChatSession.
    @Test("REGRESSION-002: stream=true on every send")
    func streamFlagAlwaysTrue() async throws {
        let mock = MockLLMService()
        mock.events = [.messageStop]
        let session = ChatSession(service: mock, model: "m", maxTokens: 100)
        for try await _ in session.send(userText: "ping") {}
        let req = mock.capturedRequests[0]
        #expect(req.stream == true,
                "stream must be true; if nil/false, streaming was accidentally disabled")
    }
}
```

Evidence: `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift`; `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:98-141`.

## Auth header regression example (L2)

```swift
@Suite("Regression: Auth Headers")
struct AuthHeaderRegressionTests {
    @Test("anthropic-version header is exactly '2023-06-01' on every send call")
    func anthropicVersionHeaderIsPinned() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: successResponseJSON, statusCode: 200)
        let client = AnthropicClient(apiKey: "sk-test-regression", transport: mock)
        _ = try await client.send(
            .init(model: "claude-sonnet-4-5-20250929", maxTokens: 256,
                  messages: [InputMessage(role: .user, content: .text("ping"))]))
        let captured = mock.capturedRequests[0]
        #expect(captured.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(captured.value(forHTTPHeaderField: "x-api-key") == "sk-test-regression")
        #expect(captured.value(forHTTPHeaderField: "content-type") == "application/json")
    }
}
```

Evidence: `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift:28-79`.

## Architectural invariant regression (source file read)

```swift
@Test("REGRESSION-002: ChatViewModel.swift contains no 'import SwiftUI'")
func chatViewModelHasNoSwiftUIImport() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let vmPath = packageRoot.appendingPathComponent("Sources/ChatCore/ChatViewModel.swift")
    let source = try String(contentsOf: vmPath, encoding: .utf8)
    #expect(!source.contains("import SwiftUI"),
            "ChatViewModel must not import SwiftUI — breaks cross-platform compilation")
}
```

Evidence: `L-capstone-multiplatform-chat/Tests/CapstoneTests/RegressionTests.swift`.
