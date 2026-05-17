// ChatMacApp.swift — SwiftUI macOS app entry point

import SwiftUI
import ChatCore
import AnthropicClient
import Foundation

@main
struct ChatMacApp: App {
    @State private var vm: ChatViewModel = {
        let envBackend = ProcessInfo.processInfo.environment["CHAT_BACKEND_URL"]
        let service: any LLMService
        if let urlString = envBackend, let url = URL(string: urlString) {
            service = BackendLLMService(baseURL: url)
        } else if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            service = AnthropicClient(apiKey: key)
        } else {
            // No service; UI will surface errors when user tries to send
            service = AnthropicClient(apiKey: "")
        }
        return ChatViewModel(service: service)
    }()

    var body: some Scene {
        WindowGroup("Claude Chat") {
            RootView(vm: vm).frame(minWidth: 500, minHeight: 600)
        }
        .windowResizability(.contentSize)
    }
}
