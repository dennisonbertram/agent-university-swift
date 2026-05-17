// CodableTests.swift — round-trip Codable tests for MessageRequest and Message

import Testing
import Foundation
@testable import AnthropicClient

// MARK: - MessageRequest Codable tests

@Suite("MessageRequest Codable")
struct MessageRequestCodableTests {

    @Test("Round-trip MessageRequest with text content")
    func roundTripTextContent() throws {
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 1024,
            messages: [InputMessage(role: .user, content: .text("Hello, Claude"))]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(MessageRequest.self, from: data)
        #expect(decoded == request)
    }

    @Test("maxTokens encodes as max_tokens in JSON")
    func maxTokensSnakeCase() throws {
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 512,
            messages: [InputMessage(role: .user, content: .text("hi"))]
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // Must have "max_tokens" key, NOT "maxTokens"
        #expect(json["max_tokens"] as? Int == 512)
        #expect(json["maxTokens"] == nil)
    }

    @Test("Content.blocks encodes as JSON array")
    func blocksContentEncoding() throws {
        let block = ContentBlock(type: "text", text: "Hello")
        let msg = InputMessage(role: .user, content: .blocks([block]))
        let encoder = JSONEncoder()
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // content must be an array
        #expect(json["content"] is [[String: Any]])
        let contentArray = json["content"] as! [[String: Any]]
        #expect(contentArray.first?["type"] as? String == "text")
        #expect(contentArray.first?["text"] as? String == "Hello")
    }

    @Test("Content.text encodes as JSON string")
    func textContentEncoding() throws {
        let msg = InputMessage(role: .user, content: .text("Hello"))
        let encoder = JSONEncoder()
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // content must be a plain string
        #expect(json["content"] as? String == "Hello")
    }

    @Test("MessageRequest with system and temperature round-trips")
    func requestWithOptionalFields() throws {
        let request = MessageRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 2048,
            messages: [InputMessage(role: .user, content: .text("Test"))],
            system: "You are a helper",
            temperature: 0.7
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(MessageRequest.self, from: data)
        #expect(decoded.system == "You are a helper")
        #expect(decoded.temperature == 0.7)
    }
}

// MARK: - Message (response) Codable tests

@Suite("Message Response Codable")
struct MessageResponseCodableTests {

    static let canonicalResponseJSON = """
    {
      "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
      "type": "message",
      "role": "assistant",
      "model": "claude-sonnet-4-5",
      "content": [
        { "type": "text", "text": "Hi! My name is Claude." }
      ],
      "stop_reason": "end_turn",
      "stop_sequence": null,
      "usage": {
        "input_tokens": 10,
        "output_tokens": 25
      }
    }
    """

    @Test("Decode canonical response JSON")
    func decodeCanonicalResponse() throws {
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message.self, from: Data(Self.canonicalResponseJSON.utf8))
        #expect(message.id == "msg_01XFDUDYJgAACzvnptvVoYEL")
        #expect(message.type == "message")
        #expect(message.role == .assistant)
        #expect(message.content.count == 1)
        #expect(message.content[0].type == "text")
        #expect(message.content[0].text == "Hi! My name is Claude.")
        #expect(message.stopReason == "end_turn")
        #expect(message.usage.inputTokens == 10)
        #expect(message.usage.outputTokens == 25)
    }

    @Test("stop_reason maps to stopReason (snake_case CodingKeys)")
    func stopReasonSnakeCase() throws {
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message.self, from: Data(Self.canonicalResponseJSON.utf8))
        #expect(message.stopReason == "end_turn")
    }

    @Test("Message round-trip encode/decode")
    func roundTripMessage() throws {
        let original = Message(
            id: "msg_test",
            type: "message",
            role: .assistant,
            content: [ContentBlock(type: "text", text: "Hello!")],
            model: "claude-sonnet-4-5-20250929",
            stopReason: "end_turn",
            stopSequence: nil,
            usage: Usage(inputTokens: 5, outputTokens: 10)
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Message.self, from: data)
        #expect(decoded == original)
    }

    @Test("Usage inputTokens/outputTokens map from snake_case JSON")
    func usageSnakeCase() throws {
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message.self, from: Data(Self.canonicalResponseJSON.utf8))
        #expect(message.usage.inputTokens == 10)
        #expect(message.usage.outputTokens == 25)
    }
}
