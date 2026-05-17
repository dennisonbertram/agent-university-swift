// Router.swift — Full implementation of the Hummingbird 2.x routing layer.
//
// Design notes:
// - Uses explicit JSONDecoder.snake.decode(...) against raw body bytes rather than
//   req.decode(as:context:), because Hummingbird's default decoder uses its own
//   JSONDecoder instance (without convertFromSnakeCase). Overriding the decoder on
//   the context requires extra plumbing; manual decoding from body bytes is simpler
//   and just as safe for this POC.
// - AnthropicError cases are mapped to HTTP status codes:
//     .unauthorized    → 401
//     .rateLimited     → 429 + Retry-After header
//     .badRequest      → 400
//     .serverError     → 502 (Bad Gateway — upstream returned 5xx)
//     other            → 500
// - SSE streaming uses ResponseBody's closure-based initializer. The closure receives
//   an `inout any ResponseBodyWriter` and writes frames synchronously as the
//   AsyncThrowingStream produces StreamEvent values.

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

// MARK: - Error response helpers

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
            if let retryAfterName = HTTPField.Name("Retry-After") {
                headers[retryAfterName] = ra
            }
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

// MARK: - Decoders

/// Decoder for inbound API requests. MessageRequest already has explicit CodingKeys
/// with snake_case strings (e.g. max_tokens = "max_tokens"), so a plain JSONDecoder
/// is all that is needed — convertFromSnakeCase would double-transform and break the
/// explicit mappings.
private let requestDecoder: JSONDecoder = JSONDecoder()

// MARK: - Body collection helper

/// Collects the request body as Data, up to 2 MB.
private func collectBodyData(_ req: Request) async throws -> Data {
    var buffer = try await req.body.collect(upTo: 2 * 1024 * 1024)
    return buffer.readData(length: buffer.readableBytes) ?? Data()
}

// MARK: - Router builder

public func buildRouter(service: any LLMService) -> Router<BasicRequestContext> {
    let router = Router()
    router.middlewares.add(LogRequestsMiddleware(.info))

    // GET /health — liveness check
    router.get("/health") { _, _ -> Response in
        let body = #"{"status":"ok"}"#
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(string: body))
        )
    }

    // POST /chat — synchronous, returns full Message JSON
    router.post("/chat") { req, _ async throws -> Response in
        let data: Data
        do {
            data = try await collectBodyData(req)
        } catch {
            return errorResponse(status: .badRequest, error: "bad_request", detail: "body collection failed: \(error)")
        }

        let payload: MessageRequest
        do {
            payload = try requestDecoder.decode(MessageRequest.self, from: data)
        } catch {
            return errorResponse(status: .badRequest, error: "bad_request", detail: "decode failed: \(error)")
        }

        do {
            let message = try await service.send(payload)
            let responseData = try JSONEncoder.snake.encode(message)
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(bytes: responseData))
            )
        } catch let e as AnthropicError {
            return mapAnthropicError(e)
        } catch {
            return errorResponse(status: .internalServerError, error: "internal", detail: "\(error)")
        }
    }

    // POST /chat/stream — SSE streaming, yields text deltas + [DONE] terminator
    router.post("/chat/stream") { req, _ async throws -> Response in
        let data: Data
        do {
            data = try await collectBodyData(req)
        } catch {
            return errorResponse(status: .badRequest, error: "bad_request", detail: "body collection failed: \(error)")
        }

        let payload: MessageRequest
        do {
            payload = try requestDecoder.decode(MessageRequest.self, from: data)
        } catch {
            return errorResponse(status: .badRequest, error: "bad_request", detail: "decode failed: \(error)")
        }

        let stream = service.stream(payload)

        // Build a streaming SSE response body. The closure receives an inout ResponseBodyWriter
        // and writes SSE frames as StreamEvents arrive.
        // - contentBlockDelta → `data: <text>\n\n`
        // - messageStop → `event: done\ndata: [DONE]\n\n` then finish
        // - stream exhausts without messageStop → still send terminator then finish
        let sseBody = ResponseBody { writer in
            do {
                for try await event in stream {
                    switch event {
                    case .contentBlockDelta(_, let text):
                        let frame = "data: \(text)\n\n"
                        try await writer.write(ByteBuffer(string: frame))
                    case .messageStop:
                        try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
                        try await writer.finish(nil)
                        return
                    default:
                        break
                    }
                }
                // Fallback: stream ended without messageStop
                try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
                try await writer.finish(nil)
            } catch {
                try await writer.finish(nil)
            }
        }

        return Response(
            status: .ok,
            headers: [.contentType: "text/event-stream", .cacheControl: "no-cache"],
            body: sseBody
        )
    }

    return router
}
