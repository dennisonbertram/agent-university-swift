// HTTPTransport.swift — protocol + URLSession-backed default implementation

import Foundation

// Note: bytes() returns AsyncThrowingStream<UInt8, Error> instead of URLSession.AsyncBytes
// because URLSession.AsyncBytes has no public initializer, making it untestable.
// URLSessionTransport adapts URLSession.AsyncBytes into AsyncThrowingStream<UInt8, Error>.

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }

    public func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse) {
        let (asyncBytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        let stream = AsyncThrowingStream<UInt8, Error> { continuation in
            Task {
                do {
                    for try await byte in asyncBytes {
                        continuation.yield(byte)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        return (stream, http)
    }
}
