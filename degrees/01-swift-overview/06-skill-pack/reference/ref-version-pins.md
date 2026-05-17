# Reference — Version Pins

[Back to index](../index.md)

All versions verified across the seven POCs in this corpus.

## Swift toolchain

| Component | Pinned version |
|-----------|---------------|
| Swift | 6.1.2 (`Apple Swift version 6.1.2`) |
| swift-tools-version | `6.1` (enables Swift 6 language mode by default) |
| swift-testing | bundled with Swift 6 — no separate package dependency |

```bash
swift --version
# Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)
```

## SwiftPM packages

| Package | Version constraint | Source |
|---------|-------------------|--------|
| `swift-argument-parser` | `.package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")` | L3 |
| `hummingbird` | `.package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0")` | L4, capstone |

Do NOT pin Hummingbird `from: "1.0.0"` — 1.x and 2.x are completely incompatible.

## Anthropic API

| Parameter | Value |
|-----------|-------|
| `anthropic-version` header | `"2023-06-01"` (literal; required on every request) |
| Default model id | `"claude-sonnet-4-5-20250929"` (dated form) |
| API base URL | `https://api.anthropic.com/v1/messages` |

Use the dated model variant (`claude-sonnet-4-5-20250929`) for reproducibility, not the rolling alias (`claude-sonnet-4-5`).

## Platform minimums

| Context | Minimum platform | Reason |
|---------|-----------------|--------|
| Any SwiftPM package | `.macOS(.v13)` | swift-testing `#isolation` macro |
| Hummingbird 2.x server | `.macOS(.v14)` | Framework requirement |
| SwiftUI with `@Observable` | `.macOS(.v14)`, `.iOS(.v17)` | `Observation` framework minimum |

## Docker images

| Stage | Image |
|-------|-------|
| Build | `swift:6.1-jammy` |
| Runtime | `swift:6.1-jammy-slim` |

Build flag: `--static-swift-stdlib` (links Swift runtime into the binary).
