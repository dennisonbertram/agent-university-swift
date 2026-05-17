# Two entry points (`main.swift` + `@main`) in the same executable target is a compile error

**Category**: gotcha

## What
A SwiftPM executable target needs exactly one entry point: either a file called `main.swift` (top-level statements allowed) or a type annotated `@main` in any non-`main.swift` file. Having both produces a hard compile error. This bites when you mix patterns — for example, an `AsyncParsableCommand` (`@main`) in a target that also has a `main.swift` from a previous iteration.

## Symptom
```
error: 'main' attribute cannot be used in a module that contains top-level code
```
or, depending on which file gets compiled first:
```
error: expressions are not allowed at the top level
```

## Cause
Both `main.swift` and `@main` register an entry point. SwiftPM cannot resolve which one to call.

## Fix
Pick one style per executable target:

- **`main.swift`** for tiny shims that just instantiate the library:
  ```swift
  // Sources/hello-spm/main.swift
  import Greeter
  let args = CommandLine.arguments
  let name = args.count > 1 ? args[1] : ""
  print(Greeter.greet(name: name))
  ```

- **`@main` struct** when you need argument parsing or an async entry:
  ```swift
  // Sources/chat/ChatCommand.swift  (NOT main.swift)
  import ArgumentParser

  @main
  struct ChatCommand: AsyncParsableCommand {
      static let configuration = CommandConfiguration(commandName: "chat", abstract: "Chat with Claude.")
      func run() async throws { /* ... */ }
  }
  ```

Do not put both in the same target.

## Evidence
- Research: `01-research/02-swiftpm-and-tooling.md` §9 FM-3 lines 411-416 — exact error texts.
- Research: `01-research/02-swiftpm-and-tooling.md` §2 lines 96-102 — "Using both is a compile error."
- POC: `L1-hello-spm/Sources/hello-spm/main.swift` — pure `main.swift`-style executable (no `@main`).
- POC: `L3-cli-chat/Sources/chat/ChatCommand.swift:8-9` — `@main struct ChatCommand: AsyncParsableCommand`; the file is named `ChatCommand.swift`, not `main.swift`.
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/main.swift` — pure top-level async (no `@main`).
- See also: planning note `degrees/01-swift-overview/02-planning/00-poc-architecture.md` L1 known risks (line 56) — "Two entry points (main.swift + @main struct) is a compile error".
