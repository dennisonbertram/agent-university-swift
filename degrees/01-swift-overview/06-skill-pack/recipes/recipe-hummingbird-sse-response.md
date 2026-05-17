# Recipe — Hummingbird SSE Response Body

[Back to index](../index.md) | See also: [lesson-07-hummingbird-http-services.md](../lessons/lesson-07-hummingbird-http-services.md) | Pattern: `patterns/hummingbird-streaming-response-body.md`

## Use this when

You need a Hummingbird 2.x route to return a `text/event-stream` SSE response from an `AsyncThrowingStream`.

## The pattern

```swift
import Hummingbird
import AnthropicClient

router.post("/chat/stream") { req, _ async throws -> Response in
    // 1. Collect and decode the request body
    let collected = try await req.body.collect(upTo: 2 * 1024 * 1024)
    let data = Data(buffer: collected)
    let payload = try JSONDecoder().decode(MessageRequest.self, from: data)

    // 2. Start the upstream stream
    let upstream = service.stream(payload)

    // 3. Build the ResponseBody closure
    let sseBody = ResponseBody { writer in
        do {
            for try await event in upstream {
                switch event {
                case .contentBlockDelta(_, let text):
                    let frame = "data: \(text)\n\n"
                    try await writer.write(ByteBuffer(string: frame))
                case .messageStop:
                    // Emit terminator and finish
                    try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
                    try await writer.finish(nil)
                    return
                default: break
                }
            }
            // Fallback: stream ended before messageStop
            try await writer.write(ByteBuffer(string: "event: done\ndata: [DONE]\n\n"))
            try await writer.finish(nil)
        } catch {
            // Error path: still finish the writer
            try await writer.finish(nil)
        }
    }

    // 4. Return the response with SSE headers
    return Response(
        status: .ok,
        headers: [
            .contentType: "text/event-stream",
            .cacheControl: "no-cache"
        ],
        body: sseBody
    )
}
```

## Rules

- Always emit the terminator on **both** the happy path AND the fallback. Otherwise SSE clients hang.
- The `writer.finish(nil)` call is required on all code paths.
- Set `Content-Type: text/event-stream` and `Cache-Control: no-cache` headers.
- Each `data: <text>\n\n` sends one SSE frame immediately — do not buffer until stream end.

## Testing the SSE route in-process

```swift
@Test("POST /chat/stream returns SSE content-type and [DONE] terminator")
func streamEndpoint() async throws {
    let mock = MockLLMService()
    mock.events = [
        .contentBlockDelta(index: 0, textDelta: "Hello"),
        .messageStop
    ]
    let router = buildRouter(service: mock)
    let app = Application(router: router)
    try await app.test(.live) { client in
        let body = ByteBuffer(string: #"{"model":"m","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}"#)
        try await client.execute(uri: "/chat/stream", method: .post,
                                 headers: [.contentType: "application/json"],
                                 body: body) { response in
            #expect(response.status == .ok)
            let ct = response.headers[.contentType]
            #expect(ct?.contains("text/event-stream") == true)
            let bodyString = response.body.map { String(buffer: $0) } ?? ""
            #expect(bodyString.contains("event: done\ndata: [DONE]\n\n"))
        }
    }
}
```

Use `app.test(.live)` (not `.router`) for the streaming route to get realistic async behaviour.

Evidence: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:175-203`; `L4-hummingbird-tool-service/Tests/ToolServiceTests/ChatStreamEndpointTests.swift`.
