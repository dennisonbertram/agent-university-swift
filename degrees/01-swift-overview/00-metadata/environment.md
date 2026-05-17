# Environment Snapshot

Captured at degree kickoff. Re-probe at the start of each phase if anything seems off.

## Host

- Machine: `Dennisons-MacBook-Pro.local`
- OS: macOS, Darwin 24.6.0
- Arch: arm64 (Apple Silicon, T6041)
- Kernel: `Darwin Kernel Version 24.6.0: Tue Apr 21 20:19:12 PDT 2026; root:xnu-11417.140.69.710.16~1/RELEASE_ARM64_T6041`

## Swift toolchain

- `swift`: `/usr/bin/swift`
- Version: Apple Swift 6.1.2 (swiftlang-6.1.2.1.2, clang-1700.0.13.5)
- swift-driver: 1.120.5
- Default target: `arm64-apple-macosx15.0`

## Xcode / Command Line Tools

- Active developer dir: `/Library/Developer/CommandLineTools` (Command Line Tools only — no full Xcode)
- `xcodebuild`: **not available** — no iOS simulator, no UIKit/SwiftUI framework SDKs.
- `xcrun`: `/usr/bin/xcrun`
- SDK path: `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`

## SwiftPM state

- `~/.swiftpm/` does not exist (fresh — will be created on first `swift build`).

## GitHub

- `gh` CLI authenticated as `dennisonbertram` (keyring).

## Implications

- All POCs MUST be buildable with `swift build` / `swift test` on Command Line Tools only.
- No POC may depend on UIKit, SwiftUI, AppKit, or an iOS Simulator.
- Capstone Docker image must use a Swift base image that matches Swift 6.1.x.
