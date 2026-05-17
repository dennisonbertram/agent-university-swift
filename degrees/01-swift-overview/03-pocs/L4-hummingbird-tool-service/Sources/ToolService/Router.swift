// Router.swift — Stub: all routes return 500 until the GREEN commit implements them.

import Foundation
import HTTPTypes
import Hummingbird
import AnthropicClient

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

// MARK: - Error helpers (stubs — used by tests even in red phase)

func errorResponse(status: HTTPResponse.Status, error: String, detail: String) -> Response {
    let body = ErrorBody(error: error, detail: detail)
    let data = (try? JSONEncoder.snake.encode(body)) ?? Data()
    return Response(
        status: status,
        headers: [.contentType: "application/json"],
        body: .init(byteBuffer: ByteBuffer(bytes: data))
    )
}

func mapAnthropicError(_ e: AnthropicError) -> Response {
    switch e {
    case .unauthorized(let body):
        return errorResponse(status: .unauthorized, error: "unauthorized", detail: body)
    case .rateLimited(let retryAfter, let body):
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        if let ra = retryAfter {
            headers[HTTPField.Name("Retry-After")!] = ra
        }
        let errorBody = ErrorBody(error: "rate_limited", detail: body)
        let data = (try? JSONEncoder.snake.encode(errorBody)) ?? Data()
        return Response(
            status: .tooManyRequests,
            headers: headers,
            body: .init(byteBuffer: ByteBuffer(bytes: data))
        )
    case .badRequest(let body):
        return errorResponse(status: .badRequest, error: "bad_request", detail: body)
    case .serverError(_, let body):
        return errorResponse(status: .badGateway, error: "upstream_error", detail: body)
    case .decodeFailure(let underlying):
        return errorResponse(status: .internalServerError, error: "decode_failure", detail: underlying)
    case .streamProtocol(let message):
        return errorResponse(status: .internalServerError, error: "stream_protocol", detail: message)
    }
}

// MARK: - Router builder

public func buildRouter(service: any LLMService) -> Router<BasicRequestContext> {
    let router = Router()
    router.middlewares.add(LogRequestsMiddleware(.info))

    // STUB: /health — will return 500 until implemented
    router.get("/health") { _, _ -> Response in
        return Response(status: .internalServerError, body: .init(byteBuffer: ByteBuffer(string: "not implemented")))
    }

    // STUB: /chat — will return 500 until implemented
    router.post("/chat") { _, _ -> Response in
        return Response(status: .internalServerError, body: .init(byteBuffer: ByteBuffer(string: "not implemented")))
    }

    // STUB: /chat/stream — will return 500 until implemented
    router.post("/chat/stream") { _, _ -> Response in
        return Response(status: .internalServerError, body: .init(byteBuffer: ByteBuffer(string: "not implemented")))
    }

    return router
}
