# Lesson 6 — CLI Tools with swift-argument-parser

[Back to index](../index.md) | Prev: [Lesson 5](lesson-05-anthropic-messages-api-streaming.md) | Next: [Lesson 7](lesson-07-hummingbird-http-services.md)

## Goal

After this lesson you can build a multi-turn CLI chat tool using `AsyncParsableCommand`, options and flags, and an actor-backed conversation state.

## Prerequisites

[Lesson 2](lesson-02-swift6-concurrency.md) — actors and async/await.
[Lesson 5](lesson-05-anthropic-messages-api-streaming.md) — streaming client.

## Concepts

### 6.1 Adding swift-argument-parser

```swift
// Package.swift
dependencies: [
    .package(path: "../L2-anthropic-client"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
],
targets: [
    .target(name: "ChatCore",
            dependencies: [.product(name: "AnthropicClient", package: "L2-anthropic-client")]),
    .executableTarget(name: "chat",
                      dependencies: [
                          "ChatCore",
                          .product(name: "ArgumentParser", package: "swift-argument-parser")
                      ])
]
```

### 6.2 `AsyncParsableCommand`

Use `AsyncParsableCommand` (not `ParsableCommand`) when `run()` needs `await`:

```swift
import ArgumentParser
import AnthropicClient
import ChatCore
import Foundation
import Darwin

@main
struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Chat with Claude from your terminal."
    )

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
                    fflush(stdout)       // flush per token to show streaming
                }
                print("\n")
            } catch { print("\n[error: \(error)]\n") }
            print("you: ", terminator: "")
        }
    }
}
```

Evidence: `L3-cli-chat/Sources/chat/ChatCommand.swift:1-47`.

### 6.3 One entry point per target

**The file is named `ChatCommand.swift`, NOT `main.swift`.**

If you add a `main.swift` AND a type annotated `@main` in the same executable target, you get:

```
error: 'main' attribute cannot be used in a module that contains top-level code
```

or:

```
error: expressions are not allowed at the top level
```

Rule: pick one style per executable target.
- `main.swift` — top-level code (simple scripts)
- `@main` struct — argument parsing or async entry

Evidence: `gotchas/main-collision-mainswift-vs-at-main.md`; `L3-cli-chat/Sources/chat/ChatCommand.swift:8-9`.

### 6.4 `@Option`, `@Argument`, `@Flag`

| Annotation | CLI shape | Example |
|------------|-----------|---------|
| `@Option(name: .long)` | `--model claude-sonnet-4-5-20250929` | Named option with value |
| `@Option(name: .short)` | `-m claude-sonnet-4-5-20250929` | Short form |
| `@Argument` | positional | `chat "Say hi"` |
| `@Flag` | `--verbose` (Bool) | Toggle without value |

Default values are set inline: `var model: String = "claude-sonnet-4-5-20250929"`.

### 6.5 Actor-backed conversation state

Multi-turn chat needs history that accumulates across calls. Wrap it in an actor:

```swift
public actor ConversationActor {
    public private(set) var messages: [InputMessage] = []

    public func append(role: Role, text: String) {
        messages.append(InputMessage(role: role, content: .text(text)))
    }

    public func appendOrExtend(role: Role, deltaText: String) {
        if let last = messages.last, last.role == role,
           case .text(let existing) = last.content {
            messages[messages.count - 1] = InputMessage(role: role, content: .text(existing + deltaText))
        } else {
            messages.append(InputMessage(role: role, content: .text(deltaText)))
        }
    }

    public func snapshot() -> [InputMessage] { messages }
    public func removeLast() { if !messages.isEmpty { messages.removeLast() } }
}
```

`appendOrExtend` coalesces consecutive same-role deltas rather than appending individual chunks.

Evidence: `L3-cli-chat/Sources/ChatCore/ConversationActor.swift:4-30`.

### 6.6 `ChatSession` — the producer

`ChatSession` is a `Sendable` struct (not an actor itself) that holds a reference to the actor:

```swift
public struct ChatSession: Sendable {
    public let history: ConversationActor
    public let service: any LLMService
    public let model: String
    public let maxTokens: Int
    public let system: String?

    public func send(userText: String) -> AsyncThrowingStream<String, Error> {
        let history = self.history     // let snapshot for @Sendable closure
        let service = self.service
        let model = self.model
        let maxTokens = self.maxTokens
        let system = self.system

        return AsyncThrowingStream { continuation in
            let task = Task {
                await history.append(role: .user, text: userText)
                let snapshot = await history.snapshot()
                let req = MessageRequest(model: model, maxTokens: maxTokens,
                                         messages: snapshot, system: system,
                                         temperature: nil, stream: true)
                var assistantStarted = false
                do {
                    for try await event in service.stream(req) {
                        try Task.checkCancellation()
                        switch event {
                        case .contentBlockDelta(_, let text):
                            if !assistantStarted {
                                await history.append(role: .assistant, text: "")
                                assistantStarted = true
                            }
                            await history.appendOrExtend(role: .assistant, deltaText: text)
                            continuation.yield(text)
                        case .messageStop:
                            continuation.finish(); return
                        default: break
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()          // keep partial state
                } catch {
                    if !assistantStarted { await history.removeLast() }   // rollback
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

Evidence: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:27-80`; `patterns/error-rollback-state-machine.md`.

## Pitfalls

- **Naming the command file `main.swift`** → compile error with `@main`. See [lesson 1](lesson-01-swift-toolchain-and-swiftpm.md#15-building-and-running).
- **Forgetting `fflush(stdout)` after each chunk** → output appears in a burst at end of stream, not token-by-token.
- **Not catching `CancellationError` separately** → Ctrl-C is treated like a network error and the conversation history is rolled back unexpectedly.

## Exercise

Complete [lab-05-cli-argparser-todo.md](../labs/lab-05-cli-argparser-todo.md): build a `todo add|list|done` CLI.

## Recap

- Use `AsyncParsableCommand` (not `ParsableCommand`) when `run()` is `async`.
- File named `ChatCommand.swift`, NOT `main.swift`. One entry point per target.
- `@Option`, `@Argument`, `@Flag` for CLI shape.
- Wrap conversation history in an `actor`. Call `snapshot()` before the stream closure.
- Error rollback: cancel keeps partial state; hard error before first delta rolls back user message.
