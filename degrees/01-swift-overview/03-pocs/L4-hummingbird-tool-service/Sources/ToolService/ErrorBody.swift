// ErrorBody.swift — JSON error response shape for all HTTP error responses.

import Hummingbird

/// Uniform error body returned for all 4xx/5xx responses.
/// Always serialized as `{"error":"<code>","detail":"<message>"}`.
public struct ErrorBody: Codable, Sendable, ResponseCodable {
    public let error: String
    public let detail: String

    public init(error: String, detail: String) {
        self.error = error
        self.detail = detail
    }
}
