// Errors.swift — AnthropicError typed error enum

public enum AnthropicError: Error, Equatable, Sendable {
    case unauthorized(body: String)
    case rateLimited(retryAfter: String?, body: String)
    case badRequest(body: String)
    case serverError(status: Int, body: String)
    case decodeFailure(underlying: String)
    case streamProtocol(message: String)
}
