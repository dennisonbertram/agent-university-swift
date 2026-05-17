// AnthropicClient.swift — main client: send() + stream()

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

    // MARK: - send

    public func send(_ request: MessageRequest) async throws -> Message {
        let urlRequest = try buildURLRequest(for: request)
        let (data, response) = try await transport.send(urlRequest)
        let body = String(decoding: data, as: UTF8.self)

        switch response.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(Message.self, from: data)
            } catch {
                throw AnthropicError.decodeFailure(underlying: error.localizedDescription)
            }
        case 400:
            throw AnthropicError.badRequest(body: body)
        case 401:
            throw AnthropicError.unauthorized(body: body)
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            throw AnthropicError.rateLimited(retryAfter: retryAfter, body: body)
        default:
            throw AnthropicError.serverError(status: response.statusCode, body: body)
        }
    }

    // MARK: - stream

    public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        var streamRequest = request
        streamRequest.stream = true
        let frozenRequest = streamRequest

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlRequest = try self.buildURLRequest(for: frozenRequest)
                    let (byteStream, response) = try await self.transport.bytes(urlRequest)

                    guard response.statusCode == 200 else {
                        let body = "stream error status \(response.statusCode)"
                        switch response.statusCode {
                        case 401:
                            continuation.finish(throwing: AnthropicError.unauthorized(body: body))
                        case 429:
                            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                            continuation.finish(throwing: AnthropicError.rateLimited(retryAfter: retryAfter, body: body))
                        default:
                            continuation.finish(throwing: AnthropicError.serverError(status: response.statusCode, body: body))
                        }
                        return
                    }

                    let eventStream = SSEParser.parse(bytes: byteStream)
                    for try await event in eventStream {
                        continuation.yield(event)
                        if case .messageStop = event {
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private helpers

    private func buildURLRequest(for request: MessageRequest) throws -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/messages")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        return urlRequest
    }
}
