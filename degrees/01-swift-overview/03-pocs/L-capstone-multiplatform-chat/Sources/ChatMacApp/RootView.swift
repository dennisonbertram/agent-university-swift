// RootView.swift — mounts ChatScreen

import SwiftUI
import ChatCore

struct RootView: View {
    @Bindable var vm: ChatViewModel
    var body: some View { ChatScreen(vm: vm) }
}
