// MessageRow.swift — single chat bubble, cross-platform

import SwiftUI
import AnthropicClient

public struct MessageRow: View {
    public let message: ChatMessage

    public init(message: ChatMessage) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message.role == .user ? "🧑" : "🤖").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.role == .user ? "You" : "Claude")
                    .font(.caption).foregroundStyle(.secondary)
                Text(message.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if message.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("typing…").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
