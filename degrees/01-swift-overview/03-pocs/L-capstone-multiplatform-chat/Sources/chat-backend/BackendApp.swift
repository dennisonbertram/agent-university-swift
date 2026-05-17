// BackendApp.swift — factory function for testable Hummingbird Application
// Inject any LLMService; tests use MockUpstreamLLMService, production uses AnthropicClient.

import ChatCore
import Hummingbird

public func buildBackend(service: any LLMService, port: Int = 0) -> some ApplicationProtocol {
    let router = buildRouter(service: service)
    return Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: port), serverName: "chat-backend")
    )
}
