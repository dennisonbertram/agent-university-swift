// StreamEvent.swift — StreamEvent enum + SSE parser

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

// MARK: - Internal SSE JSON helpers

private struct MessageStartPayload: Decodable {
    struct MessageInfo: Decodable {
        let id: String
    }
    let message: MessageInfo
}

private struct ContentBlockStartPayload: Decodable {
    struct ContentBlockInfo: Decodable {
        let type: String
    }
    let index: Int
    let contentBlock: ContentBlockInfo

    enum CodingKeys: String, CodingKey {
        case index
        case contentBlock = "content_block"
    }
}

private struct ContentBlockDeltaPayload: Decodable {
    struct Delta: Decodable {
        let type: String
        let text: String?
    }
    let index: Int
    let delta: Delta
}

private struct ContentBlockStopPayload: Decodable {
    let index: Int
}

private struct MessageDeltaPayload: Decodable {
    struct Delta: Decodable {
        let stopReason: String?
        enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
        }
    }
    struct UsageInfo: Decodable {
        let outputTokens: Int?
        enum CodingKeys: String, CodingKey {
            case outputTokens = "output_tokens"
        }
    }
    let delta: Delta
    let usage: UsageInfo?
}

// MARK: - SSEParser

struct SSEParser {
    static func parse(bytes: AsyncThrowingStream<UInt8, Error>) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var lineBuffer: [UInt8] = []
                    var currentEvent: String = ""
                    var currentData: String = ""

                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            // Process the completed line
                            let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                            lineBuffer = []

                            // Strip trailing \r if present (CRLF line endings)
                            let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line

                            if trimmed.isEmpty {
                                // Blank line = end of event; dispatch and reset
                                if !currentData.isEmpty {
                                    if currentEvent != "ping" && !currentEvent.isEmpty {
                                        if let event = try parseEvent(type: currentEvent, data: currentData) {
                                            continuation.yield(event)
                                            if case .messageStop = event {
                                                continuation.finish()
                                                return
                                            }
                                        }
                                    }
                                }
                                currentEvent = ""
                                currentData = ""
                            } else if trimmed.hasPrefix(":") {
                                // Comment line — ignore
                                continue
                            } else if trimmed.hasPrefix("event:") {
                                // Strip exactly one space after the colon if present
                                let rest = String(trimmed.dropFirst("event:".count))
                                currentEvent = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
                            } else if trimmed.hasPrefix("data:") {
                                // Strip exactly one space after the colon if present
                                let rest = String(trimmed.dropFirst("data:".count))
                                currentData = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }

                    // Handle any remaining data after EOF
                    if !lineBuffer.isEmpty {
                        let line = String(bytes: lineBuffer, encoding: .utf8) ?? ""
                        let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line
                        if !trimmed.isEmpty && !trimmed.hasPrefix(":") {
                            if trimmed.hasPrefix("data:") {
                                let rest = String(trimmed.dropFirst("data:".count))
                                currentData = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
                            }
                        }
                    }
                    if !currentData.isEmpty && !currentEvent.isEmpty && currentEvent != "ping" {
                        if let event = try parseEvent(type: currentEvent, data: currentData) {
                            continuation.yield(event)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func parseEvent(type: String, data: String) throws -> StreamEvent? {
        let jsonData = Data(data.utf8)
        let decoder = JSONDecoder()

        switch type {
        case "message_start":
            let payload = try decoder.decode(MessageStartPayload.self, from: jsonData)
            return .messageStart(messageId: payload.message.id)

        case "content_block_start":
            let payload = try decoder.decode(ContentBlockStartPayload.self, from: jsonData)
            return .contentBlockStart(index: payload.index, type: payload.contentBlock.type)

        case "content_block_delta":
            let payload = try decoder.decode(ContentBlockDeltaPayload.self, from: jsonData)
            let text = payload.delta.text ?? ""
            return .contentBlockDelta(index: payload.index, textDelta: text)

        case "content_block_stop":
            let payload = try decoder.decode(ContentBlockStopPayload.self, from: jsonData)
            return .contentBlockStop(index: payload.index)

        case "message_delta":
            let payload = try decoder.decode(MessageDeltaPayload.self, from: jsonData)
            return .messageDelta(stopReason: payload.delta.stopReason, outputTokens: payload.usage?.outputTokens)

        case "message_stop":
            return .messageStop

        default:
            return nil
        }
    }
}
