// Errors.swift — ClientError enum

public enum ClientError: Error, Equatable, Sendable {
    case badResponse
    case unauthorized
    case httpError(Int)
}
