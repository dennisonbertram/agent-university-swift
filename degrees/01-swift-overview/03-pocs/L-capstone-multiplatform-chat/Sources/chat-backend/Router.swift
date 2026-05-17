// Router.swift — STUB for RED phase
// /health, /chat, /chat/stream endpoints

import Foundation
import HTTPTypes
import Hummingbird
import AnthropicClient
import ChatCore

// MARK: - JSON coding helpers

extension JSONEncoder {
    static let snake: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
}

extension JSONDecoder {
    static let snake: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}

// MARK: - Error response body

struct ErrorBody: Codable {
    let error: String
    let detail: String
}

// MARK: - Router builder (STUB)

public func buildRouter(service: any LLMService) -> Router<BasicRequestContext> {
    let router = Router()
    // STUB: no routes registered — all requests will 404
    return router
}
