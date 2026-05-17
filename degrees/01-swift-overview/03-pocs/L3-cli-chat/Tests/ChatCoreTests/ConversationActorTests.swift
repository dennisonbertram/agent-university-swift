// ConversationActorTests.swift — swift-testing tests for ConversationActor
import Testing
import AnthropicClient
@testable import ChatCore

// MARK: - BT-001: single user message append

@Test("BT-001: append .user 'hi' → 1 message with role=.user and content=.text('hi')")
func appendSingleUserMessage() async throws {
    let actor = ConversationActor()
    await actor.append(role: .user, text: "hi")
    let msgs = await actor.snapshot()
    #expect(msgs.count == 1)
    #expect(msgs[0].role == .user)
    #expect(msgs[0].content == .text("hi"))
}

// MARK: - BT-002: 3 alternating turns → 6 messages in correct order

@Test("BT-002: 3 user+assistant turns → messages.count == 6 in alternating order")
func appendThreeAlternatingTurns() async throws {
    let actor = ConversationActor()
    await actor.append(role: .user, text: "turn1-user")
    await actor.append(role: .assistant, text: "turn1-assistant")
    await actor.append(role: .user, text: "turn2-user")
    await actor.append(role: .assistant, text: "turn2-assistant")
    await actor.append(role: .user, text: "turn3-user")
    await actor.append(role: .assistant, text: "turn3-assistant")

    let msgs = await actor.snapshot()
    #expect(msgs.count == 6)
    #expect(msgs[0].role == .user)
    #expect(msgs[0].content == .text("turn1-user"))
    #expect(msgs[1].role == .assistant)
    #expect(msgs[1].content == .text("turn1-assistant"))
    #expect(msgs[2].role == .user)
    #expect(msgs[2].content == .text("turn2-user"))
    #expect(msgs[3].role == .assistant)
    #expect(msgs[3].content == .text("turn2-assistant"))
    #expect(msgs[4].role == .user)
    #expect(msgs[4].content == .text("turn3-user"))
    #expect(msgs[5].role == .assistant)
    #expect(msgs[5].content == .text("turn3-assistant"))
}

// MARK: - appendOrExtend coalesces same-role .text

@Test("appendOrExtend coalesces into existing same-role .text message")
func appendOrExtendCoalesces() async throws {
    let actor = ConversationActor()
    await actor.append(role: .assistant, text: "Hel")
    await actor.appendOrExtend(role: .assistant, deltaText: "lo")
    await actor.appendOrExtend(role: .assistant, deltaText: "!")

    let msgs = await actor.snapshot()
    #expect(msgs.count == 1)
    #expect(msgs[0].content == .text("Hello!"))
}

// MARK: - appendOrExtend adds new message for different role

@Test("appendOrExtend adds new message when role differs")
func appendOrExtendNewRole() async throws {
    let actor = ConversationActor()
    await actor.append(role: .user, text: "Hello")
    await actor.appendOrExtend(role: .assistant, deltaText: "Hi")

    let msgs = await actor.snapshot()
    #expect(msgs.count == 2)
    #expect(msgs[0].role == .user)
    #expect(msgs[1].role == .assistant)
    #expect(msgs[1].content == .text("Hi"))
}

// MARK: - removeLast on empty is a no-op

@Test("removeLast on empty ConversationActor does not crash")
func removeLastOnEmpty() async throws {
    let actor = ConversationActor()
    // Should not crash
    await actor.removeLast()
    let count = await actor.count()
    #expect(count == 0)
}

// MARK: - count reflects message count

@Test("count returns correct number of messages")
func countReflectsMessages() async throws {
    let actor = ConversationActor()
    let initial = await actor.count()
    #expect(initial == 0)
    await actor.append(role: .user, text: "a")
    let afterOne = await actor.count()
    #expect(afterOne == 1)
    await actor.removeLast()
    let afterRemove = await actor.count()
    #expect(afterRemove == 0)
}
