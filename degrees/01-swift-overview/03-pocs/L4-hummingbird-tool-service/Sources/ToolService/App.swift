// App.swift — Application factory for tests.
//
// `buildApplication` creates a testable Hummingbird Application with the injected
// LLMService bound to port 0 (ephemeral — OS picks a free port).
// Tests use HummingbirdTesting's `.router` or `.live` test client with this factory.

import Hummingbird

public func buildApplication(service: any LLMService) -> some ApplicationProtocol {
    let router = buildRouter(service: service)
    return Application(
        router: router,
        configuration: .init(address: .hostname("127.0.0.1", port: 0))
    )
}
