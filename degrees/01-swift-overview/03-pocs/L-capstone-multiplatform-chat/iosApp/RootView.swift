// RootView.swift — NavigationStack wrapper for the iOS app
// Drop this into an Xcode iOS App project (see OPEN-IN-XCODE.md)

import SwiftUI
import ChatCore

struct RootView: View {
    @Bindable var vm: ChatViewModel

    var body: some View {
        NavigationStack {
            ChatScreen(vm: vm)
        }
    }
}
