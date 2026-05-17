# Reference — Anthropic Messages API

[Back to index](../index.md)

## Endpoint

```
POST https://api.anthropic.com/v1/messages
```

## Required headers

| Header | Value | Notes |
|--------|-------|-------|
| `x-api-key` | `$ANTHROPIC_API_KEY` | Required on every request |
| `anthropic-version` | `"2023-06-01"` | Literal string; required |
| `content-type` | `"application/json"` | Required |

## Request body fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `model` | String | Yes | Use dated form: `"claude-sonnet-4-5-20250929"` |
| `max_tokens` | Int | Yes | Required — Anthropic returns 400 if absent |
| `messages` | Array | Yes | `[{"role": "user"|"assistant", "content": "..."}]` |
| `system` | String | No | System prompt |
| `temperature` | Float | No | 0.0–1.0 |
| `stream` | Bool | No | `true` for SSE streaming |

## Response body (non-streaming)

```json
{
  "id": "msg_abc",
  "type": "message",
  "role": "assistant",
  "model": "claude-sonnet-4-5-20250929",
  "content": [{"type": "text", "text": "Hello!"}],
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {"input_tokens": 5, "output_tokens": 3}
}
```

## SSE event types (streaming)

| `event:` | Meaning |
|----------|---------|
| `message_start` | Stream begins; includes input token count |
| `content_block_start` | New content block |
| `content_block_delta` | Text delta — the chunk to display |
| `content_block_stop` | Content block done |
| `message_delta` | Stop reason and output token count |
| `message_stop` | Stream done; close the connection |
| `ping` | Keep-alive; ignore |

The stream ends with `event: message_stop`, **NOT** `data: [DONE]`.

## Error codes

| HTTP status | `error.type` | Meaning |
|-------------|-------------|---------|
| 400 | `invalid_request_error` | Bad request; usually missing `max_tokens` or malformed body |
| 401 | `authentication_error` | Missing or invalid API key |
| 403 | `permission_error` | API key lacks permission |
| 404 | `not_found_error` | Resource not found |
| 429 | `rate_limit_error` | Rate limited; check `Retry-After` header |
| 529 | *(non-standard)* | Anthropic overloaded; treat as 429 with backoff |
| 500 | `api_error` | Anthropic internal error |

Evidence: `01-research/03-anthropic-api-in-swift.md §1-§11`.
