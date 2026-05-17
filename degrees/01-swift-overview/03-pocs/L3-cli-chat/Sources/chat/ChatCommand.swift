// ChatCommand.swift — executable shim (thin, @main AsyncParsableCommand)
import ArgumentParser
import AnthropicClient
import ChatCore
import Foundation
import Darwin

@main
struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Chat with Claude from your terminal."
    )

    @Option(name: .long, help: "Anthropic model id.")
    var model: String = "claude-sonnet-4-5-20250929"

    @Option(name: .long, help: "System prompt.")
    var system: String?

    @Option(name: .long, help: "Max tokens per turn.")
    var maxTokens: Int = 1024

    func run() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
            throw ExitCode.failure
        }
        let client = AnthropicClient(apiKey: apiKey)
        let session = ChatSession(service: client, model: model, maxTokens: maxTokens, system: system)

        print("Chat with \(model). Type your message; Ctrl-D to exit.\n")
        while let line = readLine(strippingNewline: true), !line.isEmpty {
            print("\nassistant: ", terminator: "")
            do {
                for try await chunk in session.send(userText: line) {
                    print(chunk, terminator: "")
                    fflush(stdout)
                }
                print("\n")
            } catch {
                print("\n[error: \(error)]\n")
            }
            print("you: ", terminator: "")
        }
    }
}
