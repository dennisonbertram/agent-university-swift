// ChatScreen.swift — main chat screen, cross-platform SwiftUI

import SwiftUI
import AnthropicClient

public struct ChatScreen: View {
    @Bindable public var vm: ChatViewModel

    public init(vm: ChatViewModel) { self.vm = vm }

    public var body: some View {
        VStack(spacing: 0) {
            messagesScroll
            if let err = vm.errorMessage {
                Text(err).foregroundColor(.red).padding(.horizontal).padding(.bottom, 4)
            }
            InputBar(draft: $vm.draft, isStreaming: vm.isStreaming) {
                let text = vm.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                vm.draft = ""
                Task { await vm.send(userText: text) }
            } onCancel: {
                vm.cancel()
            }
        }
        .navigationTitle("Claude")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(vm.messages) { msg in
                        MessageRow(message: msg).id(msg.id)
                    }
                }
                .padding()
            }
            .onChange(of: vm.messages.last?.id) { _, newId in
                if let id = newId { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }
}
