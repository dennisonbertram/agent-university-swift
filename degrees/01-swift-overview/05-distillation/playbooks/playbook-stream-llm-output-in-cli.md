# Playbook: stream Claude output to a terminal token-by-token

**Goal**: A CLI (`swift run chat`) that reads user lines, streams the assistant response live to stdout, and survives Ctrl-C cleanly.

## Prerequisites
- A working L2-style `AnthropicClient` (see `playbooks/playbook-call-anthropic-from-swift.md`).
- `ANTHROPIC_API_KEY` exported.
- `swift-argument-parser` 1.5.0+ added to `Package.swift`.

## Steps

1. Add the argument parser to `Package.swift`:
   ```swift
   dependencies: [
       .package(path: "../L2-anthropic-client"),
       .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
   ]
   ```

2. Define an `LLMService` protocol seam and conform the existing client to it (one-line extension; see pattern `patterns/llm-service-protocol-seam.md`):
   ```swift
   public protocol LLMService: Sendable {
       func stream(_ request: MessageRequest) -> AsyncThrowingStream<StreamEvent, Error>
   }
   extension AnthropicClient: LLMService {}
   ```

3. Wrap conversation state in an actor (see pattern `patterns/actor-with-snapshot-reads.md`):
   ```swift
   public actor ConversationActor {
       public private(set) var messages: [InputMessage] = []
       public func append(role: Role, text: String) { /* ... */ }
       public func appendOrExtend(role: Role, deltaText: String) { /* coalesce same-role */ }
       public func snapshot() -> [InputMessage] { messages }
       public func removeLast() { if !messages.isEmpty { messages.removeLast() } }
   }
   ```

4. Build a `ChatSession` that turns one user turn into an `AsyncThrowingStream<String, Error>` of text deltas. Snapshot history first, then start the producer task. Set `continuation.onTermination = { _ in task.cancel() }` (see pattern `patterns/asyncthrowingstream-with-onTermination.md`).

5. Wire the CLI with `@main AsyncParsableCommand`:
   ```swift
   import ArgumentParser
   import AnthropicClient
   import ChatCore
   import Foundation
   import Darwin

   @main
   struct ChatCommand: AsyncParsableCommand {
       static let configuration = CommandConfiguration(commandName: "chat",
           abstract: "Chat with Claude from your terminal.")

       @Option(name: .long, help: "Anthropic model id.")
       var model: String = "claude-sonnet-4-5-20250929"
       @Option(name: .long, help: "System prompt.")
       var system: String?
       @Option(name: .long, help: "Max tokens per turn.")
       var maxTokens: Int = 1024

       func run() async throws {
           guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
               FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
               throw ExitCode.failure
           }
           let client = AnthropicClient(apiKey: apiKey)
           let session = ChatSession(service: client, model: model, maxTokens: maxTokens, system: system)

           print("Chat with \(model). Type your message; Ctrl-D to exit.\n")
           while let line = readLine(strippingNewline: true), !line.isEmpty {
               print("\nassistant: ", terminator: "")
               do {
                   for try await chunk in session.send(userText: line) {
                       print(chunk, terminator: "")
                       fflush(stdout)                  // flush per token
                   }
                   print("\n")
               } catch {
                   print("\n[error: \(error)]\n")
               }
               print("you: ", terminator: "")
           }
       }
   }
   ```

6. The file is named `ChatCommand.swift`, NOT `main.swift`. Two entry points is a compile error (see gotcha `gotchas/main-collision-mainswift-vs-at-main.md`).

7. Manual smoke:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-... swift run chat
   ANTHROPIC_API_KEY=sk-ant-... swift run chat --model claude-sonnet-4-5-20250929 --system "be brief"
   ```

## You'll know it worked when…
- Tokens appear one at a time on stdout, not all at once at end of stream.
- Ctrl-C cancels the in-flight stream; the next prompt is responsive (because `continuation.onTermination` cancels the producer task).
- `swift test` exercises the same `ChatSession` against a `MockLLMService` with no network.

## Evidence
- POC: `L3-cli-chat/Sources/ChatCore/LLMService.swift` — protocol seam.
- POC: `L3-cli-chat/Sources/ChatCore/ConversationActor.swift` — actor state.
- POC: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:1-81` — full streaming + rollback session.
- POC: `L3-cli-chat/Sources/chat/ChatCommand.swift:1-47` — `@main AsyncParsableCommand`.
- POC: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift` — six behavioural tests + 2 regression pins.
- See also: pattern `patterns/asyncthrowingstream-with-onTermination.md`, `patterns/error-rollback-state-machine.md`, gotcha `gotchas/anthropic-sse-has-no-done-marker.md`.
