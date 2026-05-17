// HealthClientTests.swift — BT-005: HealthClient.check() tests
// Uses withLiveBackendForURLSession for real URLSession path tests,
// and app.test(.live) for NIO path verification.

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

        try await withLiveBackendForURLSession(service: upstream) { port in
            let session = URLSession(configuration: .ephemeral)
            let healthClient = HealthClient(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!,
                session: session
            )
            let result = await healthClient.check()
            #expect(result == true)
        }
    }

    // HealthClient.check() against nothing → false
    @Test("HealthClient.check() returns false when nothing is listening")
    func checkReturnsFalseWhenNotListening() async {
        let session = URLSession(configuration: .ephemeral)
        let healthClient = HealthClient(baseURL: URL(string: "http://127.0.0.1:1")!, session: session)
        let result = await healthClient.check()
        #expect(result == false)
    }
}
