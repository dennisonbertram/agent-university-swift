// InputBar.swift — text field + send/stop button

import SwiftUI

struct InputBar: View {
    @Binding var draft: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Type a message…", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit(onSend)
                .disabled(isStreaming)
            if isStreaming {
                Button("Stop", action: onCancel)
                    .keyboardShortcut(".", modifiers: .command)
            } else {
                Button("Send", action: onSend)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }
}
