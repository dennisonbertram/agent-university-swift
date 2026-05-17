// HealthClient.swift — STUB for RED phase

import Foundation

public struct HealthClient: Sendable {
    public let baseURL: URL
    public let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func check() async -> Bool {
        // STUB: always returns false
        return false
    }
}
