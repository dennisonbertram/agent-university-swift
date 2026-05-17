# Pattern: Red / Green / Regression commit-trail TDD

**Category**: pattern

## What
Each POC progresses through three named commits per behaviour:
1. **Red**: introduce a failing test that names the expected behaviour. Source code may have a stub or be missing the feature entirely.
2. **Green**: implement the minimum code to make the test pass. No extra polish.
3. **Regression**: add a separate test in a `RegressionTests.swift` suite that pins something specific about the green commit — a header value, an SSE terminator, a field forwarding — so a future refactor that breaks it fails loudly.

The regression tests are deliberately *separate* from the behavioural tests so the named pins are visible.

## When to apply
- Every behavioural change to a non-trivial library. The corpus uses it across L2, L3, L4, L5, L6, and the capstone.

## Canonical code

L2's regression suite (auth headers):

```swift
@Suite("Regression: Auth Headers")
struct AuthHeaderRegressionTests {
    @Test("anthropic-version header is exactly '2023-06-01' on every send call")
    func anthropicVersionHeaderIsPinned() async throws {
        let mock = MockHTTPTransport()
        mock.setDataResponse(json: successResponseJSON, statusCode: 200)
        let client = AnthropicClient(apiKey: "sk-test-regression", transport: mock)
        _ = try await client.send(.init(model: "claude-sonnet-4-5-20250929", maxTokens: 256,
                                       messages: [InputMessage(role: .user, content: .text("ping"))]))
        let captured = mock.capturedRequests[0]
        #expect(captured.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    }
}
```

L3's regression for the streaming flag:
```swift
@Test("REGRESSION-002: MessageRequest always has stream=true on every send")
func streamFlagAlwaysTrue() async throws {
    // ...
    #expect(req.stream == true,
            "stream must be true; if nil/false, streaming was accidentally disabled")
}
```

L4's regression for the SSE [DONE] terminator:
```swift
@Test("POST /chat/stream [DONE] terminator is present and is the last SSE event")
func streamDoneTerminatorPresent() async throws {
    // ... triggers the route via app.test(.live) ...
    #expect(bodyString.contains("event: done\ndata: [DONE]\n\n"),
            "SSE [DONE] terminator missing from response body")
}
```

## Variants and trade-offs
- Naming convention: `REGRESSION-NNN: <description>` in the `@Test` string. Numbered per POC.
- Regression tests live in `Tests/<Module>Tests/RegressionTests.swift` next to behavioural tests.
- Each regression test has a comment block at the top explaining WHICH green commit it pins and what would break if the test fails. Example: `L4-hummingbird-tool-service/Tests/ToolServiceTests/RegressionTests.swift:1-10`.
- The `Issue.record("...")` and `#expect(... , "explain why")` patterns put diagnostic messages directly in the failure output, so a future agent reading red CI logs sees the rationale.
- The capstone's REGRESSION-002 reads a source file from disk to assert it does NOT contain `import SwiftUI` — that level of pin is appropriate when an architectural invariant is the regression target.

## Evidence
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift` — auth header regressions (lines 12-79) and SSE space regressions (lines 88-156).
- POC: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:98-141` — REGRESSION-001 (system prompt forwarding) and REGRESSION-002 (stream=true).
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/RegressionTests.swift:1-125` — three pins (Content-Type, [DONE] terminator, snake_case decode).
- POC: `L5-swiftui-macos-app/Tests/ChatAppCoreTests/ChatViewModelTests.swift:133-184` — two regressions (system prompt, isStreaming flag).
- POC: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/RegressionTests.swift:1-108` — multi-turn history + no `import SwiftUI`.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/RegressionTests.swift:1-69` — backend [DONE] + view-model SwiftUI-free.
