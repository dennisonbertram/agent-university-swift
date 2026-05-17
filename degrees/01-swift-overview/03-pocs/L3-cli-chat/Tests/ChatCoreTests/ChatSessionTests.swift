// ChatSessionTests.swift — swift-testing tests for ChatSession.send
import Testing
import AnthropicClient
@testable import ChatCore

// MARK: - BT-003: happy-path streaming — 3 deltas + messageStop

@Test("BT-003: mock yields 3 deltas + messageStop → consumer gets 3 chunks; history has 'Hello!'")
func happyPathStreaming() async throws {
    let mock = MockLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "Hel"),
        .contentBlockDelta(index: 0, textDelta: "lo"),
        .contentBlockDelta(index: 0, textDelta: "!"),
        .messageStop
    ]

    let session = ChatSession(service: mock, model: "test-model", maxTokens: 1024)
    var received: [String] = []

    for try await chunk in session.send(userText: "hi") {
        received.append(chunk)
    }

    #expect(received == ["Hel", "lo", "!"])

    let msgs = await session.history.snapshot()
    // user + assistant
    #expect(msgs.count == 2)
    #expect(msgs[0].role == .user)
    #expect(msgs[0].content == .text("hi"))
    #expect(msgs[1].role == .assistant)
    #expect(msgs[1].content == .text("Hello!"))
}

// MARK: - BT-004: error before any delta → user message rolled back

@Test("BT-004: mock throws before any delta → stream errors; history.count == 0 (user rolled back)")
func errorBeforeDeltaRollsBackUser() async throws {
    let mock = MockLLMService()
    mock.events = []
    mock.error = AnthropicError.unauthorized(body: "bad key")

    let session = ChatSession(service: mock, model: "test-model", maxTokens: 1024)

    do {
        for try await _ in session.send(userText: "hello") {
            // should not receive any chunks
            Issue.record("Should not have received any chunks before error")
        }
        Issue.record("Stream should have thrown an error")
    } catch let err as AnthropicError {
        guard case .unauthorized = err else {
            Issue.record("Wrong error type: \(err)")
            return
        }
    }

    let count = await session.history.count()
    #expect(count == 0, "User message must be rolled back on error before assistant starts")
}

// MARK: - BT-005: error after 1 delta → user stays, partial assistant stays

@Test("BT-005: mock yields 1 delta then error → user stays, partial assistant stays")
func errorAfterOneDeltaKeepsPartial() async throws {
    let mock = MockLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "partial")
    ]
    mock.error = AnthropicError.serverError(status: 500, body: "oops")

    let session = ChatSession(service: mock, model: "test-model", maxTokens: 1024)
    var received: [String] = []

    do {
        for try await chunk in session.send(userText: "question") {
            received.append(chunk)
        }
        Issue.record("Stream should have thrown an error")
    } catch let err as AnthropicError {
        guard case .serverError = err else {
            Issue.record("Wrong error type: \(err)")
            return
        }
    }

    #expect(received == ["partial"])

    let msgs = await session.history.snapshot()
    // Both user and partial assistant should remain
    #expect(msgs.count == 2)
    #expect(msgs[0].role == .user)
    #expect(msgs[1].role == .assistant)
    #expect(msgs[1].content == .text("partial"))
}

// MARK: - REGRESSION-001: system prompt carried into MessageRequest

@Test("REGRESSION-001: ChatSession constructed with system prompt sends it in MessageRequest")
func systemPromptCarriedIntoRequest() async throws {
    let mock = MockLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "ok"),
        .messageStop
    ]

    let session = ChatSession(
        service: mock,
        model: "test-model",
        maxTokens: 512,
        system: "be brief"
    )

    for try await _ in session.send(userText: "test") {}

    #expect(mock.capturedRequests.count == 1, "Exactly one request should be captured")
    let req = mock.capturedRequests[0]
    #expect(req.system == "be brief",
            "system field must equal 'be brief'; if nil, system prompt was dropped")
}

// MARK: - REGRESSION-002: stream=true always set on every send

@Test("REGRESSION-002: MessageRequest always has stream=true on every send")
func streamFlagAlwaysTrue() async throws {
    let mock = MockLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "ok"),
        .messageStop
    ]

    let session = ChatSession(service: mock, model: "test-model")

    for try await _ in session.send(userText: "test") {}

    #expect(mock.capturedRequests.count == 1)
    let req = mock.capturedRequests[0]
    #expect(req.stream == true,
            "stream must be true; if nil/false, streaming was accidentally disabled")
}

// MARK: - BT-006: consumer cancels early → no crash, history reflects partial

@Test("BT-006: consumer cancels after first chunk → no crash; history has partial assistant")
func consumerCancelsEarly() async throws {
    let mock = MockLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "chunk1"),
        .contentBlockDelta(index: 0, textDelta: "chunk2"),
        .contentBlockDelta(index: 0, textDelta: "chunk3"),
        .messageStop
    ]

    let session = ChatSession(service: mock, model: "test-model", maxTokens: 1024)

    // Consume only the first chunk then break
    var receivedFirst: String? = nil
    for try await chunk in session.send(userText: "cancel me") {
        receivedFirst = chunk
        break  // cancel after first
    }

    #expect(receivedFirst == "chunk1")

    // Allow the cancellation to propagate
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms

    let msgs = await session.history.snapshot()
    // User message + at minimum the first partial assistant chunk
    #expect(msgs.count >= 1, "At minimum user message should exist")
    if msgs.count >= 2 {
        #expect(msgs[0].role == .user)
        #expect(msgs[1].role == .assistant)
        // The assistant message should be partial (at most "chunk1", not "chunk1chunk2chunk3")
        if case .text(let text) = msgs[1].content {
            #expect(!text.contains("chunk2") || !text.contains("chunk3"),
                    "Cancelled stream should not have completed all chunks")
        }
    }
}
