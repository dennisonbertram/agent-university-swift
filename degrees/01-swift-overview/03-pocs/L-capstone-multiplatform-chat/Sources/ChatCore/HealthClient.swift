// HealthClient.swift — tiny client for /health endpoint

import Foundation

public struct HealthClient: Sendable {
    public let baseURL: URL
    public let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func check() async -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent("health"))
        req.httpMethod = "GET"
        do {
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
