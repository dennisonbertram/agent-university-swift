# Before-you-build: multiplatform SwiftPM package

Tick every box before promoting a single-platform package to multiplatform.

## Platform matrix
- [ ] You have decided the supported platforms and minimum versions. The corpus uses `.iOS(.v17)` and `.macOS(.v14)` (the minimums for `@Observable`). For backend Docker builds, the executable target builds on Linux with Swift 6 — verify no Linux-incompatible imports in the target.
- [ ] `Package.swift` declares ALL supported platforms in `platforms:` and the Xcode iOS consumer can see them. Missing iOS from `platforms:` makes Xcode reject the package.

## Dependency hygiene
- [ ] The shared library target has NO `import AppKit`, `import UIKit`, `import Combine`. Just `Foundation`, `Observation`, and (in view files) `SwiftUI`.
- [ ] The shared library target does NOT depend on Hummingbird (that pulls in NIO + a lot of transitive deps you don't want on iOS).
- [ ] If a Hummingbird-using executable is in the same package, it is a separate **product** and **target** — the iOS / macOS app products do not transitively pull Hummingbird.

## Tests
- [ ] Tests are runnable on macOS host via `swift test`. iOS-specific behaviour is documented as manual-smoke, not as a `swift test` blocker.
- [ ] At least one regression test pins architectural invariants:
  - The view model contains no `import SwiftUI` (REGRESSION-002 in L6 and capstone).
  - The backend `/chat/stream` SSE terminator is present.

## Xcode handoff
- [ ] iOS app shell is a bare Xcode iOS App project — NOT generated and committed from `swift package generate-xcodeproj` (the legacy command). The corpus ships iOS source files in an `iosApp/` directory plus an `OPEN-IN-XCODE.md` walkthrough.
- [ ] `Package.resolved` is committed if you want reproducible Xcode + `swift build` resolutions.

## CI
- [ ] CI runs `swift build` and `swift test` on macOS at minimum. iOS UI testing in CI is optional and out of scope for this corpus.

## Promotion timing — when to create the shared package
- [ ] You have at least **three** consumers of the proposed shared code (rule of three). Premature abstraction is costly; the corpus deliberately holds `AnthropicClient` in L2 until L6 needs it cross-platform.
- [ ] The shape of the shared API is stable across two consumers minimum. If consumers each want a slightly different protocol, factor the abstraction at the consumer (each defines its own `LLMService`) rather than upstream.

## Evidence
- Planning: `02-planning/01-shared-package-strategy.md` — full strategy doc; §7 spells out the promotion plan.
- POC: `L-capstone-multiplatform-chat/Package.swift:1-64` — three products, only `ChatBackendLib` pulls Hummingbird.
- POC: `L6-swiftui-ios-app/Package.swift:1-28` — earlier two-platform shared library.
- POC: `L6-swiftui-ios-app/Tests/ChatCoreSharedTests/RegressionTests.swift:60-108` — `import SwiftUI`-absent pin.
- See also: pattern `patterns/multiplatform-spm-package.md`, ADR `decision-records/adr-006-shared-library-promotion-deferred.md`.
