# Lab 5 — CLI Argument Parser: Todo Tool

[Back to index](../index.md) | Lesson: [lesson-06-cli-tools-with-argument-parser.md](../lessons/lesson-06-cli-tools-with-argument-parser.md)

## Task

Build a `todo` CLI with subcommands `add`, `list`, and `done` using `AsyncParsableCommand`.

## Deliverables

- `Sources/TodoLib/TodoStore.swift` — actor-backed todo storage
- `Sources/todo/TodoCommand.swift` — `@main AsyncParsableCommand` with subcommands
- `Tests/TodoLibTests/TodoStoreTests.swift` — tests for the store
- `swift test` exits 0
- `swift run todo add "Buy milk"` prints `Added: Buy milk [1]`
- `swift run todo list` prints all pending items
- `swift run todo done 1` marks item 1 complete

## Starter `Package.swift`

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "TodoCLI",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TodoLib", targets: ["TodoLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(name: "TodoLib"),
        .executableTarget(name: "todo",
                          dependencies: [
                              "TodoLib",
                              .product(name: "ArgumentParser", package: "swift-argument-parser")
                          ]),
        .testTarget(name: "TodoLibTests", dependencies: ["TodoLib"]),
    ]
)
```

## Requirements

### `TodoStore` (actor)

```swift
public actor TodoStore {
    public struct Item: Sendable {
        public let id: Int
        public var title: String
        public var done: Bool
    }

    public func add(title: String) -> Item   // returns the new item
    public func list() -> [Item]             // returns all items
    public func markDone(id: Int) -> Bool    // returns false if id not found
}
```

### `TodoCommand` subcommands

```
todo add "Buy milk"       → Added: Buy milk [1]
todo list                 → 1. [ ] Buy milk
                            2. [ ] Walk the dog
todo done 1               → Done: Buy milk [1]
todo list                 → 1. [x] Buy milk
                            2. [ ] Walk the dog
```

Important: the file must be named `TodoCommand.swift` (not `main.swift`). Use `@main`.

### Persistence (optional, bonus)

The lab is satisfied without persistence — the store resets on each invocation. Bonus: persist to `~/.todo.json` using `Codable`.

## Required tests for `TodoStore`

1. `add` returns an item with the correct title and `done: false`.
2. `list` returns all added items.
3. `markDone(id:)` sets the item's `done` to `true`.
4. `markDone(id: 999)` returns `false` for a non-existent id.

## Verification

```bash
swift build
swift run todo add "Buy milk"
swift run todo add "Walk the dog"
swift run todo list
swift run todo done 1
swift run todo list
swift test
```

<details>
<summary>Hint</summary>

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

    func run() async throws {
        let store = TodoStore()
        let item = await store.add(title: title)
        print("Added: \(item.title) [\(item.id)]")
    }
}
```

Each subcommand creates its own `TodoStore`. Without persistence, history resets each run — that's fine for the lab.

</details>
