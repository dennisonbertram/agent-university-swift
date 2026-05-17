// main.swift — tool-server entry point.
//
// Reads ANTHROPIC_API_KEY from the environment, binds to 0.0.0.0:8080, and serves
// the /health, /chat, and /chat/stream endpoints.

import AnthropicClient
import Hummingbird
import ToolService
import Foundation

@main
struct ToolServer {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
            exit(1)
        }
        let client = AnthropicClient(apiKey: apiKey)
        let router = buildRouter(service: client)
        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname("0.0.0.0", port: 8080),
                serverName: "tool-server"
            )
        )
        try await app.runService()
    }
}
