// ContentView.swift — main chat screen

import SwiftUI
import ChatAppCore

struct ContentView: View {
    @Bindable var vm: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Claude Chat").font(.headline)
                Spacer()
                Button("Clear") { vm.clear() }
                    .disabled(vm.messages.isEmpty || vm.isStreaming)
            }
            .padding()
            .background(.bar)

            // Messages
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
                    if let id = newId {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            if let err = vm.errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
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
    }
}
