# L4 — hummingbird-tool-service

Hummingbird 2.x HTTP service exposing Claude as a tool surface. Sync and streaming endpoints.

## What this teaches
- Hummingbird 2 routing, middleware, async handlers
- Streaming response bodies (Server-Sent Events)
- Dependency injection via protocol seam (LLMService) — testable without network
- Error mapping (typed AnthropicError → HTTP status + JSON body)
- HummingbirdTesting for in-process router tests

## Endpoints
- `GET /health` — liveness check.
- `POST /chat` — body is the Anthropic MessageRequest shape; response is the Message.
- `POST /chat/stream` — same body; response is `text/event-stream` with `data: <delta>\n\n` lines terminated by `event: done\ndata: [DONE]\n\n`.

## Build and run
```bash
export ANTHROPIC_API_KEY=...
swift build
swift run tool-server
# server on http://0.0.0.0:8080
```

## Try it
```bash
curl -X POST localhost:8080/chat \
  -H 'content-type: application/json' \
  -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":1024,"messages":[{"role":"user","content":"hi"}]}'

curl -X POST localhost:8080/chat/stream \
  -H 'content-type: application/json' \
  -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":1024,"messages":[{"role":"user","content":"hi"}]}'
```

## Run tests (no API key required)
```bash
swift test
```

## Dependencies
- `../L2-anthropic-client` (relative-path SwiftPM)
- `hummingbird` 2.x
