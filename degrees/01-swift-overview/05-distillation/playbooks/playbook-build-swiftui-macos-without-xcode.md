# Playbook: build (and possibly run) a SwiftUI macOS app with Command Line Tools only

**Goal**: Verify a SwiftUI macOS package compiles using `swift build` on a host that has CLT installed but no Xcode. Capture the limitation on `swift run`.

## Prerequisites
- macOS 14+ (the corpus targets `.macOS(.v14)` for `@Observable`).
- Apple Swift 6.1+ CLT (`xcode-select --install` gives you these).
- A SwiftPM package with `@main struct App: App`, `WindowGroup`, etc.

## Steps

1. Confirm the toolchain:
   ```bash
   swift --version
   # Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)
   # Target: arm64-apple-macosx15.0
   xcode-select -p
   # /Library/Developer/CommandLineTools
   ```

2. Make sure `platforms:` is set:
   ```swift
   platforms: [.macOS(.v14)],
   ```

3. Build:
   ```bash
   swift build
   ```
   Expect: `Build complete!` and a binary at `.build/debug/<ExecutableName>`. The verified probe completed in 34.67s.

4. Run the view-model tests:
   ```bash
   swift test
   ```
   These exercise the view model + service layer with mocks — no UI is brought up, so CLT-only is fully sufficient.

5. Try to launch the app:
   ```bash
   swift run ChatMacApp
   # OR
   open .build/debug/ChatMacApp
   ```

6. **If a window appears, you're done.** macOS LaunchServices accepted the binary and the SwiftUI run loop is alive.

7. **If no window appears**, the binary is running as a background/agent process. Three options:
   - **(a)** Wrap the binary in a minimal `.app` directory by hand: `mkdir -p MyApp.app/Contents/MacOS; cp .build/debug/ChatMacApp MyApp.app/Contents/MacOS/; cat > MyApp.app/Contents/Info.plist <<'PLIST' ... PLIST; open MyApp.app/`.
   - **(b)** Install Xcode and use `xcodebuild -scheme ChatMacApp build`.
   - **(c)** Install Xcode and run interactively. Accept the time cost.

8. iOS targets need Xcode regardless — do NOT attempt iOS builds from CLT.

## You'll know it worked when…
- `swift build` exits 0 against the SwiftUI package.
- `swift test` passes view-model logic tests without UI.
- (Optional) `swift run` launches the window. If it doesn't, the playbook still succeeded at the "compile gate" — see gotcha `gotchas/swiftui-builds-with-clt-but-cannot-launch.md` for why.

## Evidence
- Research: `01-research/05-swiftui-multiplatform.md` §8 lines 359-381 — verified probe; `Build complete! (34.67s)` exit 0.
- Research: `01-research/02-swiftpm-and-tooling.md` §5 lines 183-198 — CLT-vs-Xcode capability table.
- Planning: `02-planning/02-xcode-decision.md` §1-§7 lines 1-150 — full decision rationale and verification probe spec.
- POC: `L5-swiftui-macos-app/README.md:13-33` — "A research probe confirmed SwiftUI macOS apps compile with `swift build` on Command Line Tools alone."
- See also: gotcha `gotchas/swiftui-builds-with-clt-but-cannot-launch.md`, anti-pattern `anti-patterns/xcodebuild-for-swiftui-macos-poc.md`.
