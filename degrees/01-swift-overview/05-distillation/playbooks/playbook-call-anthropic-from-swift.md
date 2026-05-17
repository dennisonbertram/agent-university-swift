# Playbook: call Anthropic's Messages API from Swift (typed, non-streaming)

**Goal**: A working `client.send(request)` call that returns a typed `Message` value, with mockable transport, in a fresh SwiftPM library.

## Prerequisites
- `ANTHROPIC_API_KEY` exported in your shell.
- A SwiftPM library scaffolded per `playbooks/playbook-new-swiftpm-library.md`.
- No external dependencies — Foundation only.

## Steps

1. Define the Codable request and response types with **explicit `CodingKeys`** for snake_case fields. Do not use `keyDecodingStrategy = .convertFromSnakeCase` — see gotcha `gotchas/snake-case-codable-double-transform.md`.
   ```swift
   public struct MessageRequest: Codable, Sendable, Equatable {
       public var model: String
       public var maxTokens: Int                  // required, non-optional
       public var messages: [InputMessage]
       public var system: String?
       public var temperature: Double?
       public var stream: Bool?

       enum CodingKeys: String, CodingKey {
           case model
           case maxTokens = "max_tokens"
           case messages, system, temperature, stream
       }
   }
   public struct InputMessage: Codable, Sendable, Equatable {
       public var role: Role; public var content: Content
   }
   public enum Role: String, Codable, Sendable, Equatable { case user, assistant }
   public enum Content: Codable, Sendable, Equatable {
       case text(String); case blocks([ContentBlock])
       // custom init/encode that handles the string-or-array dual shape
   }
   ```

2. Define a typed error enum:
   ```swift
   public enum AnthropicError: Error, Equatable, Sendable {
       case unauthorized(body: String)
       case rateLimited(retryAfter: String?, body: String)
       case badRequest(body: String)
       case serverError(status: Int, body: String)
       case decodeFailure(underlying: String)
       case streamProtocol(message: String)
   }
   ```

3. Define a `HTTPTransport` protocol and a `URLSessionTransport` adapter (see pattern `patterns/http-transport-seam.md`):
   ```swift
   public protocol HTTPTransport: Sendable {
       func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
       func bytes(_ request: URLRequest) async throws -> (AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)
   }
   ```

4. Write the client. Map HTTP statuses to typed errors:
   ```swift
   public struct AnthropicClient: Sendable {
       public let apiKey: String
       public let baseURL: URL
       public let anthropicVersion: String
       public let transport: any HTTPTransport

       public init(apiKey: String,
                   baseURL: URL = URL(string: "https://api.anthropic.com")!,
                   anthropicVersion: String = "2023-06-01",
                   transport: any HTTPTransport = URLSessionTransport()) {
           self.apiKey = apiKey; self.baseURL = baseURL
           self.anthropicVersion = anthropicVersion; self.transport = transport
       }

       public func send(_ request: MessageRequest) async throws -> Message {
           let urlRequest = try buildURLRequest(for: request)
           let (data, response) = try await transport.send(urlRequest)
           let body = String(decoding: data, as: UTF8.self)
           switch response.statusCode {
           case 200:
               do { return try JSONDecoder().decode(Message.self, from: data) }
               catch { throw AnthropicError.decodeFailure(underlying: error.localizedDescription) }
           case 400: throw AnthropicError.badRequest(body: body)
           case 401: throw AnthropicError.unauthorized(body: body)
           case 429:
               let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
               throw AnthropicError.rateLimited(retryAfter: retryAfter, body: body)
           default: throw AnthropicError.serverError(status: response.statusCode, body: body)
           }
       }

       private func buildURLRequest(for request: MessageRequest) throws -> URLRequest {
           let url = baseURL.appendingPathComponent("v1/messages")
           var urlRequest = URLRequest(url: url)
           urlRequest.httpMethod = "POST"
           urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
           urlRequest.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
           urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
           urlRequest.httpBody = try JSONEncoder().encode(request)
           return urlRequest
       }
   }
   ```

5. Test it with `MockHTTPTransport` that returns canned JSON:
   ```swift
   @Test func successPath() async throws {
       let mock = MockHTTPTransport()
       mock.setDataResponse(json: """
         {"id":"msg_x","type":"message","role":"assistant","model":"claude-sonnet-4-5",
          "content":[{"type":"text","text":"Hi"}],"stop_reason":"end_turn","stop_sequence":null,
          "usage":{"input_tokens":1,"output_tokens":1}}
         """, statusCode: 200)
       let client = AnthropicClient(apiKey: "k", transport: mock)
       let req = MessageRequest(model: "claude-sonnet-4-5-20250929", maxTokens: 256,
                                messages: [InputMessage(role: .user, content: .text("hi"))])
       let resp = try await client.send(req)
       #expect(resp.content.first?.text == "Hi")
   }
   ```

6. Manual smoke (with a real key):
   ```bash
   ANTHROPIC_API_KEY=sk-ant-... swift run my-cli "Say hi"
   ```

## You'll know it worked when…
- `swift test` passes against the mock with no network calls.
- A manual run with a real key returns text from Claude.

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/*.swift` — full reference implementation.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/` — 33 tests covering encoding, decoding, error mapping, SSE, regressions.
- Research: `01-research/03-anthropic-api-in-swift.md` §1–§11 — full API reference.
- See also: gotcha `gotchas/max-tokens-required-on-every-anthropic-request.md`, pattern `patterns/http-transport-seam.md`, pattern `patterns/typed-error-enum-with-bodies.md`, before-you-build `before-you-build/anthropic-integration.md`.
