// ChatViewModelTests.swift — BT-001 through BT-006, swift-testing

import Testing
import AnthropicClient
@testable import ChatAppCore

@MainActor
@Suite("ChatViewModel")
struct ChatViewModelTests {

    // MARK: - BT-001: user message appears immediately on send

    @Test("BT-001: user message appears immediately — first message is user turn with correct text")
    func userMessageAppearsImmediately() async {
        let mock = MockLLMService()
        mock.events = [
            .messageStart(messageId: "m1"),
            .messageStop
        ]
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "hi")
        // After awaiting, user message must be present
        #expect(vm.messages.count >= 1, "Expected at least 1 message after send")
        #expect(vm.messages.first?.role == .user, "First message must be from user")
        #expect(vm.messages.first?.text == "hi", "User message text must be 'hi'")
    }

    // MARK: - BT-002: 3 deltas + messageStop → assistant message = "Hello!" and isStreaming == false

    @Test("BT-002: 3 deltas + messageStop → messages ends with user+assistant('Hello!'), isStreaming false")
    func deltasAccumulateIntoFinalAssistantMessage() async {
        let mock = MockLLMService()
        mock.events = [
            .contentBlockDelta(index: 0, textDelta: "He"),
            .contentBlockDelta(index: 0, textDelta: "llo"),
            .contentBlockDelta(index: 0, textDelta: "!"),
            .messageStop
        ]
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "hi")

        #expect(vm.messages.count == 2, "Expected exactly 2 messages: user + assistant")
        #expect(vm.messages[0].role == .user, "First message must be user")
        #expect(vm.messages[0].text == "hi", "User text must be 'hi'")
        #expect(vm.messages[1].role == .assistant, "Second message must be assistant")
        #expect(vm.messages[1].text == "Hello!", "Assistant must accumulate deltas to 'Hello!'")
        #expect(vm.isStreaming == false, "isStreaming must be false after messageStop")
    }

    // MARK: - BT-003: isStreaming == true while in-flight, false after completion

    @Test("BT-003: isStreaming is true mid-stream, false after messageStop")
    func isStreamingFlipsTrueThenFalse() async {
        let gated = GatedMockLLMService()
        let vm = ChatViewModel(service: gated)

        let sendTask = Task { @MainActor in
            await vm.send(userText: "hi")
        }

        // Wait 20ms — well within the 80ms pause in GatedMockLLMService
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(vm.isStreaming == true, "isStreaming must be true while stream is in flight")

        // Wait for completion
        await sendTask.value
        #expect(vm.isStreaming == false, "isStreaming must be false after stream completes")
    }

    // MARK: - BT-004: error → rolls back assistant message, surfaces errorMessage

    @Test("BT-004: AnthropicError.unauthorized → errorMessage is non-nil, isStreaming false, no assistant msg")
    func errorRollsBackAssistantMessage() async {
        let mock = MockLLMService()
        mock.events = []
        mock.error = AnthropicError.unauthorized(body: "bad key")
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "hi")

        #expect(vm.errorMessage != nil, "errorMessage must be non-nil after unauthorized error")
        #expect(vm.isStreaming == false, "isStreaming must be false after error")
        // Only user message should remain — no assistant placeholder committed
        #expect(vm.messages.count == 1, "Only the user message should remain after error rollback")
        #expect(vm.messages[0].role == .user, "Surviving message must be the user turn")
    }

    // MARK: - BT-005: cancel() mid-stream → isStreaming false, partial assistant stays

    @Test("BT-005: cancel() mid-stream — isStreaming becomes false, partial assistant message is retained")
    func cancelStopsStreamingAndKeepsPartial() async {
        let gated = GatedMockLLMService()
        let vm = ChatViewModel(service: gated)

        let sendTask = Task { @MainActor in
            await vm.send(userText: "hi")
        }

        // Wait 20ms — inside the 80ms pause so we're mid-stream
        try? await Task.sleep(nanoseconds: 20_000_000)
        #expect(vm.isStreaming == true, "Must be streaming before cancel")

        vm.cancel()

        // Give a moment for cancellation to propagate
        try? await Task.sleep(nanoseconds: 30_000_000)
        #expect(vm.isStreaming == false, "isStreaming must be false after cancel()")

        // The partial assistant message ("Hel" was already delivered) must stay
        let assistantMessages = vm.messages.filter { $0.role == .assistant }
        #expect(assistantMessages.count == 1, "Partial assistant message must be retained after cancel")

        // Clean up
        await sendTask.value
    }

    // MARK: - BT-006: clear() empties messages and errorMessage

    @Test("BT-006: clear() empties messages array and sets errorMessage to nil")
    func clearEmptiesStateCompletely() async {
        let mock = MockLLMService()
        mock.events = [.messageStop]
        let vm = ChatViewModel(service: mock)
        await vm.send(userText: "hello")
        vm.errorMessage = "some prior error"

        vm.clear()

        #expect(vm.messages.isEmpty, "messages must be empty after clear()")
        #expect(vm.errorMessage == nil, "errorMessage must be nil after clear()")
    }
}
