// MockHTTPTransport.swift — canned-response mock for tests (no network calls)

import Foundation
@testable import AnthropicClient

final class MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    var capturedRequests: [URLRequest] = []
    var dataResponse: (Data, HTTPURLResponse)?
    var bytesResponseData: Data?
    var bytesStatusCode: Int = 200
    var error: Error?

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequests.append(request)
        if let error { throw error }
        guard let dataResponse else {
            throw URLError(.badServerResponse)
        }
        return dataResponse
    }

    func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse) {
        capturedRequests.append(request)
        if let error { throw error }
        let statusCode = bytesStatusCode
        let url = request.url ?? URL(string: "https://api.anthropic.com/v1/messages")!
        guard let http = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        ) else {
            throw URLError(.badServerResponse)
        }
        let bytesData = bytesResponseData ?? Data()
        let stream = AsyncThrowingStream<UInt8, Error> { continuation in
            for byte in bytesData {
                continuation.yield(byte)
            }
            continuation.finish()
        }
        return (stream, http)
    }

    // Helper: configure a data response
    func setDataResponse(json: String, statusCode: Int, headers: [String: String] = [:]) {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let http = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        dataResponse = (Data(json.utf8), http)
    }
}
