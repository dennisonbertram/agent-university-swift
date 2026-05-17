// StreamEvent.swift — StreamEvent enum + SSE parser (STUB — unimplemented)

import Foundation

// MARK: - StreamEvent

public enum StreamEvent: Sendable, Equatable {
    case messageStart(messageId: String)
    case contentBlockStart(index: Int, type: String)
    case contentBlockDelta(index: Int, textDelta: String)
    case contentBlockStop(index: Int)
    case messageDelta(stopReason: String?, outputTokens: Int?)
    case messageStop
}

// MARK: - SSE Parser (internal)

// SSEParser reads UInt8 bytes from an AsyncThrowingStream and yields StreamEvents.
// It filters ping events and stops at message_stop.
struct SSEParser {
    static func parse(bytes: AsyncThrowingStream<UInt8, Error>) -> AsyncThrowingStream<StreamEvent, Error> {
        fatalError("unimplemented")
    }
}
