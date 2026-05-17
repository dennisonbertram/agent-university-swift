# SwiftUI macOS code COMPILES with Command Line Tools only — but `swift run` may not actually launch a window

**Category**: gotcha

## What
On macOS 15 with Swift 6.1.2 CLT-only (no Xcode.app), `import SwiftUI`, `@main struct App: App`, `WindowGroup`, etc. all compile and link. `swift build` exits 0. This is genuinely useful for CI and type-checking. But the runtime probe never confirmed that `swift run ChatMacApp` against a CLT-only toolchain produces an interactive window — the binary lacks an `.app` bundle wrapper, an `Info.plist`, code signing, and LaunchServices registration.

## Symptom
- `swift build` succeeds; the binary `.build/debug/ChatMacApp` exists.
- `swift run ChatMacApp` may print nothing and exit immediately, may run but show no window in the Dock, or may show an unfocusable window — outcomes depend on macOS LaunchServices behaviour.
- The capstone and L5 README both say `swift run ChatMacApp` "opens a window" — this is only verified anecdotally during dev, not in CI.

## Cause
Building a macOS GUI app the usual way requires a `.app` bundle with `Info.plist` keys like `LSApplicationCategoryType` and a code signature. `swift run` produces a Mach-O binary without that wrapping. macOS may classify it as a background agent and refuse to surface its windows.

## Fix
Sequence the constraint:
1. Trust `swift build` for compile verification — that part is real.
2. Trust `swift test` for the view-model unit tests — those run as a normal test process and exercise the cross-platform logic.
3. For manual demo / interactive runs of the macOS app, treat Xcode (or a hand-rolled `.app` bundle wrapper) as the path of least surprise.
4. For iOS, Xcode is mandatory anyway — no CLT-only shortcut exists.

If you must run from CLT, the planning doc lists three escape hatches: hand-build a minimal `.app` directory, use `xcodebuild`, or install Xcode.

## Evidence
- Research: `01-research/05-swiftui-multiplatform.md` §8 lines 359-381 — verified `swift build` exit 0 in 34.67s on `/tmp/swift-research-probe/swiftui-test/`; explicitly notes "CLT-only builds cannot launch or run macOS SwiftUI apps."
- Planning: `02-planning/02-xcode-decision.md` §1 lines 6-18 — separates "compiled SwiftUI code" from "produced a launchable .app bundle"; explicit list of what the probe did and did NOT verify.
- Planning: `02-planning/02-xcode-decision.md` §3 lines 40-50 — "Whether the binary launches a usable window from `swift run` in this exact Swift 6.1.2 / macOS 15 setup" is listed as unknown until tested.
- POC: `L5-swiftui-macos-app/README.md:31-33` — asserts CLT-only build works "for build purposes" but is silent on interactive runs.
- See also: ADR `decision-records/adr-009-iosapp-source-files-not-xcodeproj.md`.
