// Router.swift — /health, /chat, /chat/stream endpoints
// Ported from L4-hummingbird-tool-service with ChatCore's LLMService protocol.
//
// Design notes:
// - Uses explicit JSONDecoder (not snake_case — MessageRequest has explicit CodingKeys)
// - AnthropicError cases mapped to HTTP status codes: 401, 429+Retry-After, 400, 502, 500
// - SSE streaming: contentBlockDelta → data: <text>\n\n, messageStop → event: done\ndata: [DONE]\n\n
// - /chat/stream peeks at the first event to detect upstream errors (auth) before committing 200

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

// MARK: - Request body decoder

/// MessageRequest already has explicit CodingKeys, so a plain JSONDecoder is sufficient.
private let requestDecoder: JSONDecoder = JSONDecoder()

// MARK: - Body collection helper

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
            var fullText = ""
            for try await event in service.stream(payload) {
                if case .contentBlockDelta(_, let text) = event {
                    fullText += text
                }
            }
            let msg = Message(
                id: "msg_chat",
                type: "message",
                role: .assistant,
                content: [ContentBlock(type: "text", text: fullText)],
                model: payload.model,
                stopReason: "end_turn",
                stopSequence: nil,
                usage: Usage(inputTokens: 0, outputTokens: 0)
            )
            let responseData = try JSONEncoder.snake.encode(msg)
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

    // POST /chat/stream — SSE streaming, yields text deltas + [DONE] terminator.
    // Peeks at the stream first to detect upstream errors before committing to a 200 response.
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

        // Collect all events upfront from the upstream service.
        // This lets us detect auth errors before committing to an HTTP 200 SSE response.
        // For production use with real LLMs, this approach buffers the full response;
        // for the capstone POC (mock upstream), this is fine and correctly handles errors.
        let collectedEvents: [StreamEvent]
        do {
            var events: [StreamEvent] = []
            for try await event in service.stream(payload) {
                events.append(event)
            }
            collectedEvents = events
        } catch let e as AnthropicError {
            return mapAnthropicError(e)
        } catch {
            return errorResponse(status: .internalServerError, error: "internal", detail: "\(error)")
        }

        // Build a streaming SSE response body from the collected events.
        let sseBody = ResponseBody { writer in
            do {
                for event in collectedEvents {
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
