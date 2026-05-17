// ChatViewModelTests.swift — BT-001 through BT-005 behavioral tests, swift-testing
// TASK-L6-001

import Testing
import AnthropicClient
@testable import ChatCoreShared

// MARK: - Behavioral Tests

@MainActor
@Suite("ChatViewModel Behavioral Tests")
struct ChatViewModelTests {

    // MARK: - BT-001: system prompt forwarded into MessageRequest

    @Test("BT-001: system prompt set on init is forwarded into every MessageRequest")
    func systemPromptForwardedIntoRequest() async {
        let mock = MockLLMService()
        mock.events = [
            .contentBlockDelta(index: 0, textDelta: "ok"),
            .messageStop
        ]
        let vm = ChatViewModel(service: mock, system: "You are a helpful iOS assistant.")
        await vm.send(userText: "hi")

        #expect(mock.capturedRequests.count == 1, "Exactly one request should be captured")
        let req = mock.capturedRequests[0]
        #expect(req.system == "You are a helpful iOS assistant.",
                "system field must equal the iOS assistant prompt; if nil, system prompt was dropped")
    }

    // MARK: - BT-002: delta accumulation + messageStop → messages == [user, assistant] and isStreaming==false

    @Test("BT-002: deltas 'Hello' + ' world' + messageStop → messages=[user('hi'), assistant('Hello world')], isStreaming==false")
    func deltasAccumulateIntoFinalAssistantMessage() async {
        let mock = MockLLMService()
        mock.events = [
            .contentBlockDelta(index: 0, textDelta: "Hello"),
            .contentBlockDelta(index: 0, textDelta: " world"),
            .messageStop
        ]
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "hi")

        #expect(vm.messages.count == 2, "Expected exactly 2 messages: user + assistant")
        #expect(vm.messages[0].role == .user, "First message must be user")
        #expect(vm.messages[0].text == "hi", "User text must be 'hi'")
        #expect(vm.messages[1].role == .assistant, "Second message must be assistant")
        #expect(vm.messages[1].text == "Hello world",
                "Assistant must accumulate deltas to 'Hello world'")
        #expect(vm.isStreaming == false, "isStreaming must be false after messageStop")
    }

    // MARK: - BT-003: non-default model id is honored (regression catch: hard-coded model)

    @Test("BT-003: constructed with model='claude-haiku-X', the request uses that model id")
    func nonDefaultModelIdIsHonored() async {
        let mock = MockLLMService()
        mock.events = [.messageStop]
        let vm = ChatViewModel(service: mock, model: "claude-haiku-X")
        await vm.send(userText: "ping")

        #expect(mock.capturedRequests.count == 1, "Exactly one request captured")
        #expect(mock.capturedRequests[0].model == "claude-haiku-X",
                "Request must carry the custom model id 'claude-haiku-X'; hard-coded model would fail this")
    }

    // MARK: - BT-004: rateLimited error → errorMessage contains 'Rate limited' and retry info

    @Test("BT-004: rateLimited(retryAfter:'30') → errorMessage contains 'Rate limited' and 'retry after 30', isStreaming==false")
    func rateLimitedErrorSurfacedInErrorMessage() async {
        let mock = MockLLMService()
        mock.events = []
        mock.error = AnthropicError.rateLimited(retryAfter: "30", body: "rate limited")
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "hi")

        #expect(vm.isStreaming == false, "isStreaming must be false after rate limit error")
        let errMsg = vm.errorMessage ?? ""
        #expect(errMsg.localizedStandardContains("Rate limited") || errMsg.localizedStandardContains("rate limit"),
                "errorMessage must contain 'Rate limited'; got: \(errMsg)")
        #expect(errMsg.contains("30"),
                "errorMessage must mention the retry-after value '30'; got: \(errMsg)")
    }

    // MARK: - BT-005: multi-turn context — second send carries history from first turn

    @Test("BT-005: two sequential send() calls — second request contains prior user and assistant messages")
    func multiTurnHistoryAccumulatesAcrossSends() async {
        let mock = MockLLMService()
        // First turn
        mock.events = [
            .contentBlockDelta(index: 0, textDelta: "First response"),
            .messageStop
        ]
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "first message")

        // Reset mock for second turn
        mock.events = [
            .contentBlockDelta(index: 0, textDelta: "Second response"),
            .messageStop
        ]
        await vm.send(userText: "second message")

        #expect(mock.capturedRequests.count == 2, "Two requests should be captured (one per send)")

        // The second request should contain:
        // [user("first message"), assistant("First response"), user("second message")]
        let secondReq = mock.capturedRequests[1]
        #expect(secondReq.messages.count == 3,
                "Second request must contain 3 messages (user, assistant, user); got \(secondReq.messages.count)")
        #expect(secondReq.messages[0].role == .user, "First message in second request must be user")
        #expect(secondReq.messages[1].role == .assistant, "Second message in second request must be assistant")
        #expect(secondReq.messages[2].role == .user, "Third message in second request must be user")
        #expect(secondReq.messages[2].content == .text("second message"),
                "Third message content must be the new user turn")
    }
}
