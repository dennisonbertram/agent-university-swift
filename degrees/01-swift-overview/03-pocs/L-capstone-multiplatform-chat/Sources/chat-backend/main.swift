// main.swift — chat-backend entry point
// Uses top-level async entry (swift-tools-version 5.5+)

import Foundation
import AnthropicClient
import ChatCore
import ChatBackendLib

guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
    FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
    exit(1)
}
let client = AnthropicClient(apiKey: apiKey)
let app = buildBackend(service: client, port: 8080)
try await app.runService()
