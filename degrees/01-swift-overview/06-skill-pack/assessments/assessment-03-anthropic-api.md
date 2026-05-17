# Assessment 3 — Anthropic Messages API

[Back to index](../index.md) | Covers: [lesson-05-anthropic-messages-api-streaming.md](../lessons/lesson-05-anthropic-messages-api-streaming.md), [lesson-03-typed-clients-with-codable.md](../lessons/lesson-03-typed-clients-with-codable.md)

## Questions

**Q1.** List the three required headers for a `POST /v1/messages` request. What does Anthropic return if one is missing?

**Q2.** You model `MessageRequest` with this field:

```swift
public var maxTokens: Int?
```

Why is this wrong? What should it be?

**Q3.** You decode `MessageRequest` with:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let payload = try decoder.decode(MessageRequest.self, from: data)
```

`MessageRequest` has explicit `CodingKeys` with `case maxTokens = "max_tokens"`. What is the symptom when this runs in production? What is the fix?

**Q4.** An SSE stream from Anthropic never finishes. The consumer hangs indefinitely. Your parser is waiting for `data: [DONE]`. What is wrong and what is the fix?

**Q5.** An SSE stream works in tests but throws `decodeFailure` after 15 seconds against the live API. What is the most likely cause?

<details>
<summary>Answer Key</summary>

**A1.** The three required headers:
1. `x-api-key: <your-key>`
2. `anthropic-version: 2023-06-01`
3. `content-type: application/json`

Missing any of these returns HTTP 401 (`authentication_error`) or HTTP 400 (`invalid_request_error`).

**A2.** `maxTokens: Int?` is wrong because Anthropic requires `max_tokens` on every request — it returns HTTP 400 (`invalid_request_error: max_tokens: field required`) if it is absent. Use `maxTokens: Int` (non-optional). This pushes the requirement to every call site at compile time.

**A3.** Symptom: HTTP 400 or `Key not found: "maxTokens"` during decoding. Cause: `.convertFromSnakeCase` transforms `"max_tokens"` → `"maxTokens"` before matching `CodingKeys`, but the `CodingKey` has raw value `"max_tokens"`, not `"maxTokens"` — double-transform breaks the lookup. Fix: use a plain `JSONDecoder()` with no `keyDecodingStrategy` for types with explicit snake_case `CodingKeys`.

**A4.** Anthropic does NOT use `data: [DONE]`. The stream ends with `event: message_stop` and then closes the HTTP connection. Fix: watch for `event: message_stop` and finish the stream when it arrives.

**A5.** Anthropic sends periodic `event: ping` / `data: {"type":"ping"}` keep-alive events. The parser is not filtering them and tries to decode `ping` as a structured event, which fails. Fix: skip the decode when `currentEvent == "ping"`.

</details>
