// InputBar.swift — text field + send/stop button, cross-platform

import SwiftUI

public struct InputBar: View {
    @Binding public var draft: String
    public let isStreaming: Bool
    public let onSend: () -> Void
    public let onCancel: () -> Void

    public init(
        draft: Binding<String>,
        isStreaming: Bool,
        onSend: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._draft = draft
        self.isStreaming = isStreaming
        self.onSend = onSend
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: 8) {
            TextField("Type a message…", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit(onSend)
                .disabled(isStreaming)
                #if os(iOS)
                .submitLabel(.send)
                #endif
            if isStreaming {
                Button("Stop", action: onCancel)
            } else {
                Button("Send", action: onSend)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }
}
