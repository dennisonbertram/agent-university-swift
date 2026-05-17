// HealthClientTests.swift — BT-005: HealthClient.check() tests

import Testing
import Hummingbird
import HummingbirdTesting
import Foundation
import ChatBackendLib
@testable import ChatCore

@Suite("HealthClient")
struct HealthClientTests {

    // BT-005: HealthClient.check() against running backend → true
    @Test("HealthClient.check() returns true against running backend")
    func checkReturnsTrueAgainstRunningBackend() async throws {
        let upstream = MockUpstreamLLMService()
        let app = buildBackend(service: upstream)
        try await app.test(.live) { client in
            let port = client.port!
            let healthClient = HealthClient(baseURL: URL(string: "http://127.0.0.1:\(port)")!)
            let result = await healthClient.check()
            #expect(result == true)
        }
    }

    // HealthClient.check() against nothing → false
    @Test("HealthClient.check() returns false when nothing is listening")
    func checkReturnsFalseWhenNotListening() async {
        // Port 1 is privileged and not likely to have a server
        let healthClient = HealthClient(baseURL: URL(string: "http://127.0.0.1:1")!)
        let result = await healthClient.check()
        #expect(result == false)
    }
}
