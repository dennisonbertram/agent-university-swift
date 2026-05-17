# SSE `data: <payload>` has exactly ONE separator space — strip one, not all leading whitespace

**Category**: gotcha

## What
The W3C Server-Sent Events spec says the value of a `data:` field is the text after the colon and at most one space. If the parser does `String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)` or `drop(while: \.isWhitespace)`, payloads whose actual content starts with a space (e.g. ` world` as an assistant token continuation) are silently corrupted.

## Symptom
Assistant text loses leading spaces. Strings like `"hello world"` arrive as `"helloworld"` after streaming because each chunk is delivered as `" world"` and the parser eats the space.

## Cause
The SSE separator after `data:` is exactly one optional space, not arbitrary whitespace. The JSON payload that follows may itself begin with whitespace, and that whitespace is content, not framing.

## Fix
Strip at most one leading space, and handle both forms (`data: x` and `data:x`):

```swift
} else if trimmed.hasPrefix("data:") {
    let rest = String(trimmed.dropFirst("data:".count))
    currentData = rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest
}
```

Mirror the same logic for the `event:` field.

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/StreamEvent.swift:107-113` — the canonical fix; `rest.hasPrefix(" ") ? String(rest.dropFirst()) : rest`.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift:88-156` — `@Suite("Regression: SSE space handling")`. Three pinned cases: one space stripped, leading space in JSON value preserved, no-space form (`data:{...}`) handled.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift:114-135` — `leadingSpaceInJSONPayloadPreserved` test pins that `text == " world"` is preserved verbatim.
- Research: `01-research/03-anthropic-api-in-swift.md` §5 lines 118-153 — SSE line format.
- See also: pattern `patterns/sse-line-parsing.md`.
