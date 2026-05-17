// BackendLLMService.swift — client-side LLMService that talks to /chat/stream on the backend
// Parses simplified SSE protocol: data: <text>\n\n + event: done\ndata: [DONE]\n\n

import AnthropicClient
import Foundation

public struct BackendLLMService: LLMService {
    public let baseURL: URL
    public let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        let url = baseURL.appendingPathComponent("chat/stream")

        return AsyncThrowingStream { continuation in
            // Capture immutable copies for Sendable closure
            let sessionCapture = session
            let requestCapture = request

            let task = Task {
                do {
                    // 1. Encode request body (MessageRequest already has explicit CodingKeys)
                    let encoder = JSONEncoder()
                    let bodyData = try encoder.encode(requestCapture)

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = bodyData

                    // 2. Open SSE stream from URLSession.bytes
                    let (bytes, response) = try await sessionCapture.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ClientError.badResponse)
                        return
                    }
                    if http.statusCode == 401 {
                        continuation.finish(throwing: ClientError.unauthorized)
                        return
                    }
                    if http.statusCode >= 400 {
                        continuation.finish(throwing: ClientError.httpError(http.statusCode))
                        return
                    }

                    // 3. Iterate lines. SSE frames:
                    //    data: Hello\n\n
                    //    event: done\ndata: [DONE]\n\n
                    var i = 0
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        if line.hasPrefix("data: ") {
                            let payload = String(line.dropFirst(6))
                            if payload == "[DONE]" {
                                continuation.yield(.messageStop)
                                continuation.finish()
                                return
                            }
                            continuation.yield(.contentBlockDelta(index: i, textDelta: payload))
                            i += 1
                        }
                        // event: lines and blank lines are ignored
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
