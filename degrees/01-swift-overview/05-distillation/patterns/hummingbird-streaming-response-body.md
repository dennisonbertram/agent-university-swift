# Pattern: Hummingbird streaming `ResponseBody` driven by an `AsyncThrowingStream`

**Category**: pattern

## What
To return an SSE response from a Hummingbird 2.x route, build the body with `ResponseBody { writer in ... }`. Inside the closure, iterate the upstream `AsyncThrowingStream`, format each event as an SSE frame, and `try await writer.write(ByteBuffer(string: frame))`. End the stream by writing your termination frame and calling `try await writer.finish(nil)`. Set the response headers to `[.contentType: "text/event-stream", .cacheControl: "no-cache"]`.

## When to apply
- Whenever a Hummingbird route returns an open-ended stream of data: SSE, chunked text, NDJSON.

## Canonical code

```swift
import Hummingbird
import AnthropicClient

router.post("/chat/stream") { req, _ async throws -> Response in
    let data = try await collectBodyData(req)
    let payload = try requestDecoder.decode(MessageRequest.self, from: data)
    let upstream = service.stream(payload)

    let sseBody = ResponseBody { writer in
        do {
            for try await event in upstream {
                switch event {
                case .contentBlockDelta(_, let text):
                    let frame = "data: \(text)\n\n"
                    try await writer.write(ByteBuffer(string: frame))
                case .messageStop:
                    try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
                    try await writer.finish(nil)
                    return
                default: break
                }
            }
            // Stream ended without messageStop — still emit terminator
            try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
            try await writer.finish(nil)
        } catch {
            try await writer.finish(nil)
        }
    }

    return Response(
        status: .ok,
        headers: [.contentType: "text/event-stream", .cacheControl: "no-cache"],
        body: sseBody
    )
}
```

## Variants and trade-offs
- The closure signature receives an `inout any ResponseBodyWriter`; mutation is `try await writer.write(...)` / `try await writer.finish(nil)`.
- Always emit the terminator on both the happy path AND the fallback (stream ended before `messageStop`). Otherwise SSE clients hang waiting for a closing event.
- Writing `data: <text>\n\n` per delta sends one SSE frame per chunk; the browser / curl client sees it immediately. Buffering until end-of-stream nullifies the value.
- If you need to detect upstream errors before committing to a 200 SSE response, you can drain the upstream first and only THEN open the writer. The capstone does this deliberately — see ADR `decision-records/adr-008-buffered-vs-streaming-chat-stream-in-capstone.md` for the trade-off.

## Evidence
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:175-203` — true streaming variant.
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/Router.swift:182-225` — buffered variant; deliberate choice for test reliability with mocks.
- POC: `L4-hummingbird-tool-service/Tests/ToolServiceTests/ChatStreamEndpointTests.swift:17-90` — three tests covering SSE content-type, terminator, malformed input.
- Research: `01-research/04-hummingbird.md` §5 lines 171-209 — `Response`, `ResponseBody` types.
- Research: `01-research/04-hummingbird.md` §12 FM-2 lines 412-415 — "Blocking synchronous work in handlers" warning.
- See also: gotcha `gotchas/hummingbird-test-live-vs-router-transport.md`, ADR `decision-records/adr-008-buffered-vs-streaming-chat-stream-in-capstone.md`.
