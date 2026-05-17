# Pre-flight Checklist — Before Writing an Anthropic API Integration

[Back to index](../index.md) | Related: [ai-system-prompt-swift.md](ai-system-prompt-swift.md), [lesson-05](../lessons/lesson-05-anthropic-messages-api-streaming.md)

Run through this list before writing any Anthropic API client code.

---

## Authentication

- [ ] `ANTHROPIC_API_KEY` is read from environment: `ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]`
- [ ] The key is never hardcoded in source
- [ ] If the key is absent, the code throws or exits with an error message to stderr — not a force-unwrap crash

## Request headers — all three are required

- [ ] `x-api-key: <key>` is set
- [ ] `anthropic-version: 2023-06-01` is set (exact string — no other version)
- [ ] `content-type: application/json` is set
- [ ] Missing any of these causes 401 or 400 — verify all three are present before testing

## Request body

- [ ] `model` field is set to `claude-sonnet-4-5-20250929` (default) or the caller-specified model
- [ ] `max_tokens` is set — it is required; the API has no default
- [ ] `max_tokens` is non-optional in the Swift struct (`Int`, not `Int?`)
- [ ] `messages` is an array of `{role, content}` objects
- [ ] For streaming: `"stream": true` is included in the request body — NOT as a header

## Codable — the double-transform trap

- [ ] Do NOT set `jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase` on any decoder used with these types
- [ ] `maxTokens` maps to `"max_tokens"` via explicit `CodingKeys`
- [ ] All other snake_case fields also have explicit `CodingKeys` entries
- [ ] This applies to both request encoding AND response decoding

## SSE streaming

- [ ] The SSE parser reads byte-by-byte into a line buffer and dispatches on blank lines (the frame boundary)
- [ ] The one-space rule: strip exactly `"data: "` (7 chars: d-a-t-a-colon-space) from each data line
- [ ] Lines starting with `"event: ping"` are discarded — do not try to decode them as JSON
- [ ] The stream ends when `event: message_stop` is received — there is NO `data: [DONE]` marker
- [ ] After receiving `message_stop`, the continuation is finished (not on the next blank line)

## Stream termination

- [ ] `continuation.finish()` is called after `message_stop`
- [ ] `continuation.finish(throwing:)` is called if an error occurs mid-stream
- [ ] `continuation.finish()` is also called in the `onTermination` handler if the task is cancelled before completion
- [ ] The stream does NOT hang waiting for a `[DONE]` marker that never arrives

## Transport seam

- [ ] HTTP calls go through `any HTTPTransport` — not a direct `URLSession` call
- [ ] `AnthropicClient` is initialised with an injected `transport: any HTTPTransport`
- [ ] `URLSessionTransport` is the production implementation; `MockHTTPTransport` is used in tests

## Request body encoding

- [ ] Use `JSONEncoder()` with default settings — do NOT set `outputFormatting` or `keyEncodingStrategy`
- [ ] The encoded `Data` is set as `request.httpBody`
- [ ] `httpMethod` is `"POST"`

## Error handling

- [ ] HTTP status codes are checked before parsing the body
- [ ] 401 → missing or wrong API key
- [ ] 429 → rate limited; back off and retry
- [ ] 400 → malformed request (check headers, max_tokens, stream flag)
- [ ] Streaming errors mid-stream are propagated via `continuation.finish(throwing:)`

## Tests

- [ ] A `MockLLMService` with canned events covers the happy path without hitting the network
- [ ] A test verifies the three required headers are present on the `URLRequest`
- [ ] A test verifies that `message_stop` terminates the stream
- [ ] A test verifies ping lines are filtered (no JSON parse error on ping)

---

See also: [recipe-anthropic-client-init](../recipes/recipe-anthropic-client-init.md), [recipe-streaming-sse-consumer](../recipes/recipe-streaming-sse-consumer.md), [ref-anthropic-messages-api](../reference/ref-anthropic-messages-api.md)

Evidence: `05-distillation/gotchas/anthropic-sse-has-no-done-marker.md`, `05-distillation/patterns/sse-line-parsing.md`, `05-distillation/patterns/http-transport-seam.md`.
