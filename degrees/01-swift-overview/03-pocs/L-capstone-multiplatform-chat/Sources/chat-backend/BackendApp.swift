// BackendApp.swift — STUB for RED phase
// Factory function for testable Hummingbird Application

import ChatCore
import Hummingbird

public func buildBackend(service: any LLMService, port: Int = 0) -> some ApplicationProtocol {
    // STUB: returns a minimal non-functional application
    let router = Router<BasicRequestContext>()
    return Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: port), serverName: "chat-backend")
    )
}
