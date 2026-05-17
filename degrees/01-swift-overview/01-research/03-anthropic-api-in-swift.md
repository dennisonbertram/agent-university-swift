# Anthropic Messages API in Swift

> Source: https://platform.claude.com/docs/en/api/messages (accessed 2026-05-16)
> Source: https://platform.claude.com/docs/en/api/messages-streaming (accessed 2026-05-16)

---

## 1. API Endpoint and Authentication

```
POST https://api.anthropic.com/v1/messages
```

**Required headers**:
```
x-api-key: <ANTHROPIC_API_KEY>
anthropic-version: 2023-06-01
content-type: application/json
```

**Convention**: read the key from environment variable `ANTHROPIC_API_KEY`. Never hardcode.

```swift
let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
```

---

## 2. Request Body Shape

### Minimal request (required fields only)

```json
{
  "model": "claude-sonnet-4-5",
  "max_tokens": 1024,
  "messages": [
    { "role": "user", "content": "Hello, Claude" }
  ]
}
```

### Full field reference

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `model` | string | ✅ | See current model IDs below |
| `messages` | array | ✅ | Array of `{role, content}` |
| `max_tokens` | integer | ✅ | Maximum output tokens |
| `system` | string \| array | ❌ | System prompt |
| `stream` | boolean | ❌ | `true` for SSE streaming |
| `tools` | array | ❌ | Tool definitions |
| `tool_choice` | object | ❌ | `auto`/`any`/`tool`/`none` |
| `temperature` | float | ❌ | 0.0–1.0, default 1.0 |
| `stop_sequences` | string[] | ❌ | Custom stop strings |

### Message content

Content can be a string (shorthand) or an array of typed blocks:

```json
{ "role": "user", "content": "Hello" }
// equivalent to:
{ "role": "user", "content": [{ "type": "text", "text": "Hello" }] }
```

---

## 3. Current Model IDs (as of 2026-05)

Source: https://platform.claude.com/docs/en/api/messages

| Model ID | Description | Recommended for |
|----------|-------------|-----------------|
| `claude-opus-4-7` | Latest frontier, long-running agents | Complex tasks, agents |
| `claude-sonnet-4-6` | Best speed/intelligence balance | General use |
| `claude-haiku-4-5` | Fastest, near-frontier | Low-latency |
| `claude-sonnet-4-5` | High-performance coding/agents | Coding, tool use |
| `claude-opus-4-5` | Premium maximum intelligence | Complex reasoning |

**Recommended default for POCs**: `claude-sonnet-4-5` — good balance of capability and cost. Use the dated variant `claude-sonnet-4-5-20250929` for reproducibility.

**Important**: Model IDs change frequently. Always pin a dated variant (e.g., `claude-sonnet-4-5-20250929`) in production code so behavior doesn't change under you.

---

## 4. Response Body Shape

```json
{
  "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
  "type": "message",
  "role": "assistant",
  "model": "claude-sonnet-4-5",
  "content": [
    { "type": "text", "text": "Hi! My name is Claude." }
  ],
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {
    "input_tokens": 10,
    "output_tokens": 25,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 0
  }
}
```

**`stop_reason` values**: `end_turn`, `max_tokens`, `stop_sequence`, `tool_use`, `pause_turn`, `refusal`

---

## 5. SSE Streaming Format

Set `"stream": true` in the request body. The response is Server-Sent Events.

### SSE Line format

```
event: <event-name>
data: <json-payload>
\n
```

### Event sequence for a text response

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_...","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":1}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: ping
data: {"type":"ping"}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"!"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":15}}

event: message_stop
data: {"type":"message_stop"}
```

Source: https://platform.claude.com/docs/en/api/messages-streaming (full example in fetched docs)

### Content block delta types

| Delta type | Field | Usage |
|-----------|-------|-------|
| `text_delta` | `text: String` | Text content chunks |
| `input_json_delta` | `partial_json: String` | Tool input chunks (accumulate, then parse) |
| `thinking_delta` | `thinking: String` | Extended thinking content |
| `signature_delta` | `signature: String` | Thinking block signature |

### Ping events

The API sends `ping` events periodically to keep the connection alive. **Your parser must handle them** — ignore by type check:

```swift
if eventType == "ping" { continue }
```

### End of stream

Anthropic does **NOT** use `data: [DONE]` (that's OpenAI). The stream ends with:
```
event: message_stop
data: {"type":"message_stop"}
```

After `message_stop`, the HTTP connection closes. Your parser should handle EOF after this event.

---

## 6. Tool Use

### Request with tools

```json
{
  "model": "claude-sonnet-4-5",
  "max_tokens": 1024,
  "tools": [
    {
      "name": "get_weather",
      "description": "Get current weather for a location.",
      "input_schema": {
        "type": "object",
        "properties": {
          "location": { "type": "string", "description": "City name" }
        },
        "required": ["location"]
      }
    }
  ],
  "tool_choice": { "type": "auto" },
  "messages": [
    { "role": "user", "content": "What's the weather in Paris?" }
  ]
}
```

### Tool use response (stop_reason == "tool_use")

```json
{
  "stop_reason": "tool_use",
  "content": [
    {
      "type": "tool_use",
      "id": "toolu_01T1x1fJ34qAmk2tNTrN7Up6",
      "name": "get_weather",
      "input": { "location": "Paris" }
    }
  ]
}
```

### Tool result follow-up

```json
{
  "messages": [
    { "role": "user", "content": "What's the weather in Paris?" },
    {
      "role": "assistant",
      "content": [
        { "type": "tool_use", "id": "toolu_01...", "name": "get_weather", "input": {"location": "Paris"} }
      ]
    },
    {
      "role": "user",
      "content": [
        {
          "type": "tool_result",
          "tool_use_id": "toolu_01...",
          "content": "15°C, partly cloudy"
        }
      ]
    }
  ]
}
```

---

## 7. Codable Types for Swift Client

The following types are synthesized from the API specification and SSE format. These are designed for Swift 6 with `Codable`.

```swift
// MARK: - Request Types

struct MessagesRequest: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let system: String?
    let stream: Bool?
    let tools: [Tool]?
    let toolChoice: ToolChoice?
    let temperature: Double?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, system, stream, tools, temperature
        case maxTokens = "max_tokens"
        case toolChoice = "tool_choice"
    }
}

struct Message: Codable {
    let role: String  // "user" or "assistant"
    let content: MessageContent
}

// Content can be a string or array of blocks
enum MessageContent: Codable {
    case text(String)
    case blocks([ContentBlock])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            self = .blocks(try container.decode([ContentBlock].self))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .blocks(let b): try container.encode(b)
        }
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: AnyCodable?
    let toolUseId: String?
    let content: MessageContent?
    let isError: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, content
        case toolUseId = "tool_use_id"
        case isError = "is_error"
    }
}

// MARK: - Tool Types

struct Tool: Encodable {
    let name: String
    let description: String
    let inputSchema: JSONSchema
    
    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct JSONSchema: Encodable {
    let type: String
    let properties: [String: PropertySchema]
    let required: [String]?
}

struct PropertySchema: Encodable {
    let type: String
    let description: String?
}

struct ToolChoice: Encodable {
    let type: String  // "auto", "any", "tool", "none"
    let name: String?  // only for type "tool"
}

// MARK: - Response Types

struct MessagesResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let model: String
    let content: [ContentBlock]
    let stopReason: String?
    let stopSequence: String?
    let usage: Usage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, model, content, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

struct Usage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - SSE Stream Event Types

struct StreamEvent: Decodable {
    let type: String
    let index: Int?
    let message: MessagesResponse?
    let contentBlock: ContentBlockStart?
    let delta: StreamDelta?
    let usage: StreamUsage?
    let error: StreamError?
    
    enum CodingKeys: String, CodingKey {
        case type, index, message, delta, usage, error
        case contentBlock = "content_block"
    }
}

struct ContentBlockStart: Decodable {
    let type: String  // "text", "tool_use", etc.
    let text: String?
    let id: String?
    let name: String?
}

struct StreamDelta: Decodable {
    let type: String  // "text_delta", "input_json_delta", "stop_reason"
    let text: String?
    let partialJson: String?
    let stopReason: String?
    let stopSequence: String?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case partialJson = "partial_json"
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

struct StreamUsage: Decodable {
    let outputTokens: Int?
    enum CodingKeys: String, CodingKey {
        case outputTokens = "output_tokens"
    }
}

struct StreamError: Decodable {
    let type: String
    let message: String
}
```

---

## 8. Recommended Swift Client Architecture

Build a typed client using `URLSession` async APIs + `AsyncThrowingStream` for streaming.

```swift
// Non-streaming request
actor AnthropicClient {
    private let apiKey: String
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(apiKey: String = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "") {
        self.apiKey = apiKey
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
    }
    
    func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        let httpRequest = try buildRequest(body: request, stream: false)
        let (data, response) = try await session.data(for: httpRequest)
        try validate(response: response)
        return try decoder.decode(MessagesResponse.self, from: data)
    }
    
    // Streaming request — yields parsed StreamEvents
    func stream(_ request: MessagesRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var req = request
                    // stream: true is set in buildRequest
                    let httpRequest = try self.buildRequest(body: req, stream: true)
                    let (bytes, response) = try await self.session.bytes(for: httpRequest)
                    try self.validate(response: response)
                    
                    // SSE parsing: accumulate lines
                    var eventType: String = ""
                    for try await line in bytes.lines {
                        if line.hasPrefix("event: ") {
                            eventType = String(line.dropFirst(7))
                        } else if line.hasPrefix("data: ") {
                            let data = Data(line.dropFirst(6).utf8)
                            if eventType == "ping" { continue }
                            let event = try self.decoder.decode(StreamEvent.self, from: data)
                            continuation.yield(event)
                            if eventType == "message_stop" {
                                continuation.finish()
                                return
                            }
                        }
                        // blank line = end of event; reset
                        // (handled implicitly by the line-by-line parsing)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func buildRequest(body: MessagesRequest, stream: Bool) throws -> URLRequest {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(body)
        return req
    }
    
    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        switch http.statusCode {
        case 200: return
        case 401: throw AnthropicError.unauthorized
        case 429: throw AnthropicError.rateLimited
        case 529: throw AnthropicError.overloaded
        default: throw AnthropicError.httpError(http.statusCode)
        }
    }
}

enum AnthropicError: Error {
    case invalidResponse
    case unauthorized          // 401 — bad or missing API key
    case rateLimited           // 429
    case overloaded            // 529 — high load (Anthropic-specific)
    case httpError(Int)
    case sseParseError(String)
}
```

---

## 9. Existing Swift SDKs — Quality Assessment

**No official Anthropic Swift SDK exists as of 2026-05.** Anthropic officially ships SDKs for Python, TypeScript, Go, Java, PHP, Ruby. Swift is not in that list.

Source: GitHub org search `https://api.github.com/orgs/anthropics/repos` — only Swift repo is `anthropics/swift-markdown-ui` (a UIKit/SwiftUI markdown renderer, unrelated to API client).

### Community Swift SDKs Found

| Package | Stars | Version | Swift 6 | Status |
|---------|-------|---------|---------|--------|
| `fumito-ito/AnthropicSwiftSDK` | 18 | 0.14.0 | Unclear | Single maintainer, active |
| `GeorgeLyon/SwiftClaude` | 73 | None (branch only) | ✅ (requires) | Pre-1.0, self-described "under-tested" |
| `guitaripod/AnthropicKit` | 3 | Unknown | Unknown | Tiny community |

**Recommendation for this POC stack**: Build a minimal typed client directly (as shown above). Reasons:
1. No official SDK — no parity guarantee with API changes
2. Community SDKs are pre-1.0, low-star, single-maintainer
3. The API surface needed for L2/L3 is small: non-streaming send + SSE stream
4. Direct URLSession + Codable + AsyncThrowingStream is idiomatic Swift 6

If you need more features (tool use with full SDK support), `fumito-ito/AnthropicSwiftSDK` 0.14.0 covers streaming, tool use, prompt caching, and Computer Use. Acceptable for prototyping.

---

## 10. Failure Modes

### FM-1: Missing or wrong API key

**HTTP 401**. Error body: `{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}`

**Fix**: check `ANTHROPIC_API_KEY` env var is set and non-empty before making requests.

### FM-2: Invalid model ID

**HTTP 400**. Body: `{"type":"error","error":{"type":"invalid_request_error","message":"model: ..."}}`

**Fix**: use exact model strings from the docs. `claude-sonnet-4-5` is valid; `claude-3.5-sonnet` is NOT (old format).

### FM-3: Rate limit (429)

**HTTP 429**. Retry-After header may be present. Body: `{"type":"error","error":{"type":"rate_limit_error"}}`

**Fix**: exponential backoff. Anthropic's rate limits apply per API key per minute.

### FM-4: Overload (529)

Anthropic-specific status code. During high load, returns 529 (not 503). In SSE stream, may also arrive as:
```
event: error
data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}
```

**Fix**: treat 529 like 429 — backoff and retry.

### FM-5: SSE `[DONE]` parsing bug

**Expectation gap**: OpenAI's streaming API ends with `data: [DONE]`. Anthropic does NOT. If you copy an OpenAI SSE parser that checks for `[DONE]`, you'll either hang or miss the `message_stop` event.

**Anthropic's termination**: `event: message_stop` / `data: {"type":"message_stop"}`. After this, the HTTP connection closes.

### FM-6: Tool input JSON is delivered as partial strings

During streaming, `tool_use` block deltas deliver `partial_json` strings that must be **accumulated** before parsing. Do NOT try to decode JSON on each delta — it's not valid JSON until `content_block_stop`:

```swift
var toolInputAccumulator = ""
if delta.type == "input_json_delta" {
    toolInputAccumulator += delta.partialJson ?? ""
}
// Only decode after content_block_stop
if eventType == "content_block_stop" {
    let toolInput = try JSONDecoder().decode([String: Any].self, 
                                            from: Data(toolInputAccumulator.utf8))
}
```

### FM-7: `max_tokens` is required

Unlike some LLM APIs, `max_tokens` is required in every request. Omitting it causes a 400 error.

---

## 11. URLSession Async APIs Reference

```swift
// Non-streaming: load all data at once
let (data, response) = try await URLSession.shared.data(for: request)

// Streaming: bytes line by line (macOS 12+, iOS 15+)
let (bytes, response) = try await URLSession.shared.bytes(for: request)
for try await line in bytes.lines {
    // process SSE line
}
```

`URLSession.shared.bytes(for:)` returns an `URLSession.AsyncBytes` which is `AsyncSequence`. Its `.lines` property wraps it in a `Lines` sequence that splits on newlines — exactly what SSE parsing needs.

---

## Sources

- https://platform.claude.com/docs/en/api/messages — full request/response spec (accessed 2026-05-16)
- https://platform.claude.com/docs/en/api/messages-streaming — SSE event format and examples (accessed 2026-05-16)
- GitHub API: `https://api.github.com/orgs/anthropics/repos` — confirmed no Swift API client
- GitHub search: `anthropic swift sdk` — community SDK inventory
- https://github.com/fumito-ito/AnthropicSwiftSDK — 0.14.0, last release Jul 2025
- https://github.com/GeorgeLyon/SwiftClaude — main branch, pre-1.0, Swift 6 required
