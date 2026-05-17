// SSEParserTests.swift — SSE parser unit tests

import Testing
import Foundation
@testable import AnthropicClient

// Helper: build an AsyncThrowingStream<UInt8, Error> from a string
func makeByteStream(from string: String) -> AsyncThrowingStream<UInt8, Error> {
    let bytes = Array(string.utf8)
    return AsyncThrowingStream { continuation in
        for byte in bytes {
            continuation.yield(byte)
        }
        continuation.finish()
    }
}

// Helper: collect all events from a stream
func collectEvents(from stream: AsyncThrowingStream<StreamEvent, Error>) async throws -> [StreamEvent] {
    var events: [StreamEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

@Suite("SSE Parser")
struct SSEParserTests {

    @Test("Parser emits messageStart event")
    func parsesMessageStart() async throws {
        let sse = """
        event: message_start\r
        data: {"type":"message_start","message":{"id":"msg_abc123","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let eventStream = SSEParser.parse(bytes: byteStream)
        let events = try await collectEvents(from: eventStream)
        #expect(events.count >= 1)
        if case .messageStart(let id) = events[0] {
            #expect(id == "msg_abc123")
        } else {
            Issue.record("Expected messageStart, got \(events[0])")
        }
    }

    @Test("Parser emits contentBlockDelta events")
    func parsesContentBlockDelta() async throws {
        let sse = """
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let eventStream = SSEParser.parse(bytes: byteStream)
        let events = try await collectEvents(from: eventStream)
        #expect(events.count >= 1)
        if case .contentBlockDelta(let index, let text) = events[0] {
            #expect(index == 0)
            #expect(text == "Hello")
        } else {
            Issue.record("Expected contentBlockDelta, got \(events[0])")
        }
    }

    @Test("Parser filters ping events — ping does NOT appear in output")
    func filtersPingEvents() async throws {
        let sse = """
        event: ping\r
        data: {"type":"ping"}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let eventStream = SSEParser.parse(bytes: byteStream)
        let events = try await collectEvents(from: eventStream)
        // messageStop is emitted; ping is NOT in the output
        for event in events {
            if case .messageStart = event { continue }
            if case .contentBlockStart = event { continue }
            if case .contentBlockDelta = event { continue }
            if case .contentBlockStop = event { continue }
            if case .messageDelta = event { continue }
            if case .messageStop = event { continue }
            Issue.record("Unexpected event type: \(event)")
        }
        // Verify none of the events came from ping (they're all typed StreamEvents — ping has no case)
        // The fact we can enumerate all cases without a ping case proves filtering
        #expect(events.count == 1) // Only messageStop should be present
        #expect(events[0] == .messageStop)
    }

    @Test("Parser handles events separated by blank lines")
    func handlesBlankLineSeparation() async throws {
        let sse = """
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"A"}}\r
        \r
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"B"}}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let eventStream = SSEParser.parse(bytes: byteStream)
        let events = try await collectEvents(from: eventStream)
        #expect(events.count == 3)
        if case .contentBlockDelta(_, let text) = events[0] {
            #expect(text == "A")
        }
        if case .contentBlockDelta(_, let text) = events[1] {
            #expect(text == "B")
        }
        #expect(events[2] == .messageStop)
    }

    @Test("Parser ignores comment lines starting with ':'")
    func ignoresCommentLines() async throws {
        let sse = """
        : this is a comment\r
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let eventStream = SSEParser.parse(bytes: byteStream)
        let events = try await collectEvents(from: eventStream)
        #expect(events.count == 2)
        if case .contentBlockDelta(_, let text) = events[0] {
            #expect(text == "Hi")
        }
    }

    @Test("Full SSE sequence yields events in order")
    func fullSSESequence() async throws {
        let sse = """
        event: message_start\r
        data: {"type":"message_start","message":{"id":"msg_xyz","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}\r
        \r
        event: content_block_start\r
        data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\r
        \r
        event: ping\r
        data: {"type":"ping"}\r
        \r
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\r
        \r
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"!"}}\r
        \r
        event: content_block_stop\r
        data: {"type":"content_block_stop","index":0}\r
        \r
        event: message_delta\r
        data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let eventStream = SSEParser.parse(bytes: byteStream)
        let events = try await collectEvents(from: eventStream)

        // ping is filtered, so we expect 7 events (not 8)
        #expect(events.count == 7)
        // Check order
        if case .messageStart(let id) = events[0] {
            #expect(id == "msg_xyz")
        } else {
            Issue.record("Expected messageStart at index 0, got \(events[0])")
        }
        if case .contentBlockStart(let idx, let type_) = events[1] {
            #expect(idx == 0)
            #expect(type_ == "text")
        } else {
            Issue.record("Expected contentBlockStart at index 1")
        }
        if case .contentBlockDelta(let idx, let text) = events[2] {
            #expect(idx == 0)
            #expect(text == "Hello")
        }
        if case .contentBlockDelta(let idx, let text) = events[3] {
            #expect(idx == 0)
            #expect(text == "!")
        }
        if case .contentBlockStop(let idx) = events[4] {
            #expect(idx == 0)
        }
        if case .messageDelta(let reason, _) = events[5] {
            #expect(reason == "end_turn")
        }
        #expect(events[6] == .messageStop)
    }

    @Test("SSE data: with single space after colon preserves exact text content")
    func sseDataSpaceStripping() async throws {
        // 'data: Hello' — the space after ':' is the separator, 'Hello' is the value
        let sse = """
        event: content_block_delta\r
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" leading space"}}\r
        \r
        event: message_stop\r
        data: {"type":"message_stop"}\r
        \r

        """
        let byteStream = makeByteStream(from: sse)
        let eventStream = SSEParser.parse(bytes: byteStream)
        let events = try await collectEvents(from: eventStream)
        #expect(events.count == 2)
        if case .contentBlockDelta(_, let text) = events[0] {
            // The text content has a leading space because the JSON says " leading space"
            // but the SSE 'data: ' prefix space is stripped (only one space after the colon)
            #expect(text == " leading space")
        }
    }
}
