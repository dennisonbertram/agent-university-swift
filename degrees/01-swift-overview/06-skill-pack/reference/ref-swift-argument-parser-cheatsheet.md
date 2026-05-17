# Reference — swift-argument-parser Cheat Sheet

[Back to index](../index.md)

Package: `.package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")`
Import: `import ArgumentParser`

## `AsyncParsableCommand`

Use when `run()` needs `async`:

```swift
import ArgumentParser

@main
struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Chat with Claude."
    )

    func run() async throws {
        // async work here
    }
}
```

**File must NOT be named `main.swift`** when using `@main`. Use `ChatCommand.swift`.

## Options, arguments, flags

```swift
// Named option: --model claude-sonnet-4-5-20250929
@Option(name: .long, help: "Model id.")
var model: String = "claude-sonnet-4-5-20250929"

// Short option: -m value
@Option(name: .short, help: "Short name.")
var message: String

// Combined: --max-tokens 1024 or -n 1024
@Option(name: [.short, .long], help: "Max tokens.")
var maxTokens: Int = 1024

// Optional option (absent = nil)
@Option(name: .long, help: "System prompt.")
var system: String?

// Positional argument (required)
@Argument(help: "The prompt text.")
var prompt: String

// Flag (Bool, defaults false)
@Flag(name: .long, help: "Enable verbose output.")
var verbose: Bool = false
```

## Subcommands

```swift
@main
struct TodoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "todo",
        subcommands: [AddCommand.self, ListCommand.self, DoneCommand.self]
    )
}

struct AddCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add")
    @Argument var title: String
    func run() async throws { /* ... */ }
}
```

## Error handling

```swift
func run() async throws {
    guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
        FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
        throw ExitCode.failure
    }
}
```

## CLI output per token

```swift
for try await chunk in session.send(userText: line) {
    print(chunk, terminator: "")
    fflush(stdout)    // flush per chunk so tokens appear in real time
}
print("\n")
```

Evidence: `L3-cli-chat/Sources/chat/ChatCommand.swift`; `01-research/02-swiftpm-and-tooling.md §7`.
