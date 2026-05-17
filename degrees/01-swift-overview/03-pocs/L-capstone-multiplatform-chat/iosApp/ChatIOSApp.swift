// ChatIOSApp.swift — @main App entry point for iOS
// Drop this into an Xcode iOS App project (see OPEN-IN-XCODE.md)

import SwiftUI
import ChatCore
import AnthropicClient
import Foundation

@main
struct ChatIOSApp: App {
    @State private var vm: ChatViewModel = {
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        let client = AnthropicClient(apiKey: apiKey)
        return ChatViewModel(service: client)
    }()

    var body: some Scene {
        WindowGroup {
            RootView(vm: vm)
        }
    }
}
