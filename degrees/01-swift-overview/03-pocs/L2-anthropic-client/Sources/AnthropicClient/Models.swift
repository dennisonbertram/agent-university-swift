// Models.swift — Codable request/response types for the Anthropic Messages API

import Foundation

// MARK: - AnyCodable helper
// Enum-backed to satisfy Swift 6 Sendable requirements (AnyHashable is not Sendable)

public enum AnyCodable: Codable, Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Role

public enum Role: String, Codable, Sendable, Equatable {
    case user
    case assistant
}

// MARK: - Content

public enum Content: Codable, Sendable, Equatable {
    case text(String)
    case blocks([ContentBlock])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .blocks(try container.decode([ContentBlock].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s):
            try container.encode(s)
        case .blocks(let b):
            try container.encode(b)
        }
    }
}

// MARK: - ContentBlock

public struct ContentBlock: Codable, Sendable, Equatable {
    public var type: String
    public var text: String?
    public var id: String?
    public var name: String?
    public var input: [String: AnyCodable]?

    public init(type: String, text: String? = nil, id: String? = nil, name: String? = nil, input: [String: AnyCodable]? = nil) {
        self.type = type
        self.text = text
        self.id = id
        self.name = name
        self.input = input
    }
}

// MARK: - InputMessage

public struct InputMessage: Codable, Sendable, Equatable {
    public var role: Role
    public var content: Content

    public init(role: Role, content: Content) {
        self.role = role
        self.content = content
    }
}

// MARK: - MessageRequest

public struct MessageRequest: Codable, Sendable, Equatable {
    public var model: String
    public var maxTokens: Int
    public var messages: [InputMessage]
    public var system: String?
    public var temperature: Double?
    public var stream: Bool?

    public init(model: String, maxTokens: Int, messages: [InputMessage], system: String? = nil, temperature: Double? = nil, stream: Bool? = nil) {
        self.model = model
        self.maxTokens = maxTokens
        self.messages = messages
        self.system = system
        self.temperature = temperature
        self.stream = stream
    }

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case temperature
        case stream
    }
}

// MARK: - Usage

public struct Usage: Codable, Sendable, Equatable {
    public var inputTokens: Int
    public var outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Message (response)

public struct Message: Codable, Sendable, Equatable {
    public var id: String
    public var type: String
    public var role: Role
    public var content: [ContentBlock]
    public var model: String
    public var stopReason: String?
    public var stopSequence: String?
    public var usage: Usage

    public init(id: String, type: String, role: Role, content: [ContentBlock], model: String, stopReason: String? = nil, stopSequence: String? = nil, usage: Usage) {
        self.id = id
        self.type = type
        self.role = role
        self.content = content
        self.model = model
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}
