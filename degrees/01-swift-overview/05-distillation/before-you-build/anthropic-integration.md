# Before-you-build: Anthropic integration

Tick every box before writing the first Anthropic call from Swift.

## Environment
- [ ] `echo $ANTHROPIC_API_KEY | head -c 12` shows `sk-ant-...`. The key is non-empty AND readable from the process that will run your code (Xcode scheme env var, container env, shell rc).
- [ ] You are NOT hardcoding the key in source. Use `ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]`.

## Model id and pinning
- [ ] Pin a **dated** model variant for reproducibility — e.g. `claude-sonnet-4-5-20250929`, not the rolling `claude-sonnet-4-5` alias. The corpus uses the dated form across L2–capstone.
- [ ] The model id matches a current entry from `https://platform.claude.com/docs/en/api/messages`. LLM-suggested ids like `claude-3.5-sonnet` are wrong (old format).

## Headers
- [ ] Outgoing request sets ALL THREE: `x-api-key: <key>`, `anthropic-version: 2023-06-01`, `content-type: application/json`. The corpus's L2 client and its three regression tests pin this.

## Request body
- [ ] `max_tokens` is set. It is required. Model `maxTokens` as a non-optional `Int` in your Swift struct (see gotcha `gotchas/max-tokens-required-on-every-anthropic-request.md`).
- [ ] If you will stream, `stream: true` is set on the request. The streaming method on the client should also flip it internally (defensive double set; see anti-pattern `anti-patterns/forgetting-stream-true-on-streaming-request.md`).
- [ ] Snake_case fields use **explicit `CodingKeys`** with snake_case raw values, NOT `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` (see gotcha `gotchas/snake-case-codable-double-transform.md`).

## Streaming
- [ ] Termination is `event: message_stop`, NOT `data: [DONE]` (see gotcha `gotchas/anthropic-sse-has-no-done-marker.md`).
- [ ] Parser ignores `event: ping` lines (see gotcha `gotchas/sse-ping-events-must-be-ignored.md`).
- [ ] SSE separator handling strips at most ONE space after `data:` (see gotcha `gotchas/sse-data-space-is-one-character.md`).

## Errors
- [ ] HTTP 401 → `unauthorized(body:)`. HTTP 429 → `rateLimited(retryAfter:body:)` with `Retry-After` forwarded. HTTP 529 → treat as overload, retry with backoff (Anthropic-specific status). HTTP 5xx → `serverError(status:body:)`.
- [ ] Decode failures wrap into a typed `decodeFailure(underlying:)`, not raw `try!` crashes.

## Tests
- [ ] Tests use a `MockHTTPTransport` (or `MockLLMService`) — no live API calls in `swift test`.
- [ ] You have at least one regression test pinning critical request shape (auth headers, `stream: true`, system prompt forwarding).

## Evidence
- Research: `01-research/03-anthropic-api-in-swift.md` — full reference for headers, model ids, request body, SSE.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift:28-79` — auth header regression pins.
- POC: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:124-141` — `stream: true` regression pin.
- POC: `L2-anthropic-client/Sources/AnthropicClient/AnthropicClient.swift:30-46` — status code → error mapping.
