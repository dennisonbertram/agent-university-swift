// ChatMacApp.swift — @main App entry point (STUB)

import SwiftUI
import ChatAppCore
import AnthropicClient
import Foundation

@main
struct ChatMacApp: App {
    @State private var viewModel: ChatViewModel = {
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        let client = AnthropicClient(apiKey: apiKey)
        return ChatViewModel(service: client)
    }()

    var body: some Scene {
        WindowGroup("Claude Chat") {
            ContentView(vm: viewModel)
                .frame(minWidth: 500, minHeight: 600)
        }
        .windowResizability(.contentSize)
    }
}
