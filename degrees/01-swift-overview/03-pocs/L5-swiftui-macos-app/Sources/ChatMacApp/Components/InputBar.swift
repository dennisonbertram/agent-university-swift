// InputBar.swift — text field + send/stop button (STUB)

import SwiftUI

struct InputBar: View {
    @Binding var draft: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Text("TODO")
    }
}
