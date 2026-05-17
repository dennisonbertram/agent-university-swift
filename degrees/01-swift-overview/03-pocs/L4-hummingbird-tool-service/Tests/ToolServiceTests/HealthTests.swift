// HealthTests.swift — BT-001: GET /health returns 200 with {"status":"ok"}

import Testing
import Hummingbird
import HummingbirdTesting
@testable import ToolService

@Suite("Health endpoint")
struct HealthTests {

    // BT-001: When GET /health is called, the response is 200 OK with JSON body {"status":"ok"}
    @Test("GET /health returns 200 with status:ok body")
    func getHealthReturns200() async throws {
        let mock = MockLLMService()
        let app = buildApplication(service: mock)

        try await app.test(.router) { client in
            try await client.execute(uri: "/health", method: .get) { response in
                #expect(response.status == .ok)
                let bodyString = String(buffer: response.body)
                #expect(bodyString.contains("\"status\""))
                #expect(bodyString.contains("\"ok\""))
            }
        }
    }
}
