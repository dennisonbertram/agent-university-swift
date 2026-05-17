// AnthropicClient.swift — main client: send() + stream() (STUB — unimplemented)

import Foundation

public struct AnthropicClient: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let anthropicVersion: String
    public let transport: any HTTPTransport

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        anthropicVersion: String = "2023-06-01",
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
        self.transport = transport
    }

    public func send(_ request: MessageRequest) async throws -> Message {
        fatalError("unimplemented")
    }

    public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        fatalError("unimplemented")
    }
}
