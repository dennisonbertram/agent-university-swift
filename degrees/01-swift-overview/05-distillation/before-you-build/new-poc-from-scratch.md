# Before-you-build: a new POC from scratch

A pre-flight checklist for kicking off any new SwiftPM POC in this style. Inherits from `before-you-build/swift6-concurrency-task.md` plus the topic-specific lists.

## Toolchain
- [ ] `swift --version` shows 6.1+ (`Apple Swift version 6.1.2 ...`).
- [ ] Decision on Xcode: needed for iOS targets, NOT needed for macOS-only library / CLI / Hummingbird POCs.

## Package.swift
- [ ] `swift-tools-version: 6.1` at the top.
- [ ] `platforms:` declared (always — see gotcha `gotchas/swift-package-init-omits-platforms.md`).
- [ ] Library target + executable target are separate (see pattern `patterns/library-target-plus-thin-executable-shim.md`).
- [ ] Sibling SwiftPM deps wired with `.package(path: "../<sibling>")` until the rule of three triggers promotion to a real package.

## Tests
- [ ] swift-testing is used (`import Testing`, `@Test`, `#expect`, `#require`). No package dependency needed — bundled with Swift 6.
- [ ] At least one `MockXyzService` test double exists for every external boundary.
- [ ] At least one `RegressionTests.swift` suite with named `REGRESSION-NNN: ...` pins.

## Layout convention
- [ ] `Sources/<LibTarget>/...` for library code.
- [ ] `Sources/<ExecTarget>/main.swift` or `<ExecTarget>/<Command>.swift` for entry — exactly one entry point (see gotcha `gotchas/main-collision-mainswift-vs-at-main.md`).
- [ ] `Tests/<LibTarget>Tests/...`.

## TDD discipline
- [ ] You will follow the red/green/regression commit trail (see pattern `patterns/red-green-regression-tdd-trail.md`). Red commit names the behaviour with a failing test; green is the minimum implementation; regression is a separate pinned test.

## Topic-specific pre-flights (apply when relevant)
- [ ] If calling Anthropic: see `before-you-build/anthropic-integration.md`.
- [ ] If running a server: see `before-you-build/hummingbird-service.md`.
- [ ] If shipping SwiftUI: see `before-you-build/swiftui-multiplatform.md`.
- [ ] If multiplatform (iOS + macOS): see `before-you-build/multiplatform-spm-package.md`.

## Evidence
- POC: every POC in this corpus follows the layout and TDD discipline above.
- Planning: `02-planning/00-poc-architecture.md` — each POC's "Known risks" section is the original surface area of this list.
- See also: playbook `playbooks/playbook-new-swiftpm-library.md`.
