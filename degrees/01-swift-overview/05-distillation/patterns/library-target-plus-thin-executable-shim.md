# Pattern: library target holds the logic, executable target is a thin shim

**Category**: pattern

## What
Every executable POC in this corpus splits into two targets:
1. A **library target** (`Greeter`, `ChatCore`, `ToolService`, `ChatAppCore`, etc.) that holds the testable logic, value types, and protocol seams.
2. An **executable target** (`hello-spm`, `chat`, `tool-server`, `ChatMacApp`) that is 5-30 lines of wiring: read env, construct the library types, hand off to the library.

The test target depends on the library, not the executable, because executable targets cannot generally be imported back into tests.

## When to apply
- Always, for any SwiftPM executable that has logic worth testing.
- Especially when you have an `AsyncParsableCommand` — keep the command struct's `run()` method tiny and delegate to library code.

## Canonical code

`Package.swift` shape (capstone backend):

```swift
.target(name: "ChatBackendLib",
        dependencies: [
            "ChatCore",
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "AnthropicClient", package: "L2-anthropic-client")
        ],
        path: "Sources/chat-backend",
        exclude: ["main.swift"]),                    // <-- library excludes the entry point

.executableTarget(name: "chat-backend",
                  dependencies: ["ChatBackendLib", "ChatCore",
                                 .product(name: "AnthropicClient", package: "L2-anthropic-client")],
                  path: "Sources/chat-backend",
                  sources: ["main.swift"]),          // <-- executable is just main.swift

.testTarget(name: "CapstoneTests",
            dependencies: ["ChatCore", "ChatBackendLib",
                           .product(name: "HummingbirdTesting", package: "hummingbird"),
                           ...])
```

The actual `main.swift` is tiny:

```swift
// Sources/chat-backend/main.swift
import Foundation
import AnthropicClient
import ChatCore
import ChatBackendLib

guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
    FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
    exit(1)
}
let client = AnthropicClient(apiKey: apiKey)
let app = buildBackend(service: client, port: 8080)
try await app.runService()
```

All of the routing, error mapping, and Hummingbird wiring lives in `ChatBackendLib` (`buildRouter`, `buildBackend`) where it can be imported by `CapstoneTests`.

## Variants and trade-offs
- The capstone uses the `exclude` / `sources` split on a shared `Sources/chat-backend/` directory — the library target compiles everything except `main.swift`, the executable target compiles only `main.swift`.
- For simpler POCs (L1, L3, L4, L5) the two targets live in separate directories: `Sources/Greeter/` (lib) vs `Sources/hello-spm/main.swift` (exe).
- Argument parsing typically lives in the executable target since `@main` belongs there; the `run()` function then calls into library code:
  ```swift
  // L3 chat — ChatCommand.swift
  @main
  struct ChatCommand: AsyncParsableCommand {
      func run() async throws {
          let session = ChatSession(service: AnthropicClient(apiKey: key), model: model, ...)
          // delegate to ChatCore types
      }
  }
  ```

## Evidence
- POC: `L1-hello-spm/Package.swift:10-17` — `Greeter` library + `hello-spm` executable.
- POC: `L3-cli-chat/Package.swift:11-37` — `ChatCore` library + `chat` executable + `ChatCoreTests` against the library.
- POC: `L4-hummingbird-tool-service/Package.swift:9-37` — `ToolService` library + `tool-server` executable.
- POC: `L5-swiftui-macos-app/Package.swift:10-31` — `ChatAppCore` library + `ChatMacApp` executable.
- POC: `L-capstone-multiplatform-chat/Package.swift:28-48` — `ChatBackendLib` target with `exclude: ["main.swift"]` plus matching `chat-backend` executable with `sources: ["main.swift"]`.
- POC: `L4-hummingbird-tool-service/Sources/tool-server/main.swift:12-29` — entire executable target is a 17-line `ToolServer`.
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/main.swift:1-15` — 15 lines total.
