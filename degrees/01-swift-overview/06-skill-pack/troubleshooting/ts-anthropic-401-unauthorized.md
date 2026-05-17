# Troubleshooting — HTTP 401 from Anthropic

[Back to index](../index.md)

## Symptom

```json
{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}
```

HTTP 401 from `POST https://api.anthropic.com/v1/messages`.

## Diagnosis

One or more required headers are missing or malformed:

| Header | Required value |
|--------|---------------|
| `x-api-key` | Your `ANTHROPIC_API_KEY` |
| `anthropic-version` | `"2023-06-01"` (exactly this string) |
| `content-type` | `"application/json"` |

Common causes:
1. `ANTHROPIC_API_KEY` is not exported in the shell running the process.
2. The header name is wrong (e.g. `Authorization: Bearer` instead of `x-api-key`).
3. The `anthropic-version` value is wrong or missing.

## Fix

```swift
private func buildURLRequest(for request: MessageRequest) throws -> URLRequest {
    let url = baseURL.appendingPathComponent("v1/messages")
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")            // not Authorization
    urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
    urlRequest.httpBody = try JSONEncoder().encode(request)
    return urlRequest
}
```

Check the key is set:

```bash
echo $ANTHROPIC_API_KEY | head -c 12
# Should show: sk-ant-...
```

## Regression pin

Write a test that asserts the headers on every request:

```swift
@Test("anthropic-version header is pinned to '2023-06-01'")
func versionHeaderPinned() async throws {
    let mock = MockHTTPTransport()
    mock.setDataResponse(json: successJSON, statusCode: 200)
    let client = AnthropicClient(apiKey: "sk-test", transport: mock)
    _ = try await client.send(testRequest)
    let captured = mock.capturedRequests[0]
    #expect(captured.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    #expect(captured.value(forHTTPHeaderField: "x-api-key") == "sk-test")
}
```

Evidence: `L2-anthropic-client/Tests/AnthropicClientTests/RegressionTests.swift:28-79`.

## See also

- Lesson: [lesson-05-anthropic-messages-api-streaming.md](../lessons/lesson-05-anthropic-messages-api-streaming.md)
- Before-you-build: `before-you-build/anthropic-integration.md`
