# Pattern: relative-path SwiftPM dependencies for sibling POCs

**Category**: pattern

## What
When several SwiftPM packages live in sibling directories (as the POCs in this corpus do), wire dependencies with `.package(path: "../<sibling>")` rather than a git URL or release tag. This means a regression in the upstream package is felt immediately when the downstream package's tests run — no `swift package update` churn, no version drift.

## When to apply
- Monorepo-style projects with multiple co-evolving SwiftPM packages.
- Teaching / proof-of-concept progressions where each level builds on the previous (this corpus).
- Pre-1.0 internal libraries before you split them into separate repositories.

## Canonical code

`L3-cli-chat/Package.swift`:
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L3-cli-chat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "chat", targets: ["chat"]),
        .library(name: "ChatCore", targets: ["ChatCore"])
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client"),     // <-- sibling POC
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(name: "ChatCore",
                dependencies: [.product(name: "AnthropicClient", package: "L2-anthropic-client")]),
        .executableTarget(name: "chat",
                          dependencies: ["ChatCore",
                                         .product(name: "ArgumentParser", package: "swift-argument-parser")])
    ]
)
```

The product name (`AnthropicClient`) is what L2 exposes; the package name (`L2-anthropic-client`) is the directory.

## Variants and trade-offs
- L3, L4, L5, L6, and the capstone all consume L2 this way. Modifying L2 invalidates downstream builds immediately, which is the desired teaching loop.
- Trade-off: relative paths break when you move a package outside the sibling layout. Once a package stabilises, promote it to a tagged release URL.
- For Docker / CI: the Dockerfile in the capstone explicitly documents that `COPY ../L2-anthropic-client ./L2-anthropic-client/` requires changing the build context — see ADR `decision-records/adr-006-shared-library-promotion-deferred.md` and [playbook-dockerize-swift-server.md](../playbooks/playbook-dockerize-swift-server.md) (the Dockerfile sibling-dep caveat is covered in the playbook; no standalone gotcha).
- Promote to a real package only when the rule of three is satisfied: third consumer signals the abstraction is stable.

## Evidence
- POC: `L3-cli-chat/Package.swift:13-15` — `.package(path: "../L2-anthropic-client")`.
- POC: `L4-hummingbird-tool-service/Package.swift:14` — same.
- POC: `L5-swiftui-macos-app/Package.swift:14` — same.
- POC: `L6-swiftui-ios-app/Package.swift:13-14` — same.
- POC: `L-capstone-multiplatform-chat/Package.swift:16` — same.
- Planning: `02-planning/01-shared-package-strategy.md` §7 lines 234-249 — "Promotion plan: when does the shared package come into existence?" — describes the rule of three.
- See also: ADR `decision-records/adr-006-shared-library-promotion-deferred.md`, playbook `playbooks/playbook-dockerize-swift-server.md`.
