# Readiness Assessment — Swift Degree 01

## Verdict
**READY** — with the explicit caveats listed below.

## Scope confirmed
Server/CLI Swift + LLM integration + macOS + iOS frontends, per `00-metadata/scope.md` and the `command-intent.md` scope amendment. Capstone unifies all surfaces.

## Phase status

| Phase | Status | Evidence |
|-------|--------|----------|
| 0 — Metadata + environment probe | Complete | `00-metadata/` (degree.md, scope.md, poc-plan.md, environment.md, assumptions.md) |
| 1 — Research kickoff | Complete | Folded into Phase 2 |
| 2 — Research | Complete | `01-research/` — 7 files, ~2920 lines, 9 runtime probes, 15 expectation gaps, sources cited |
| 3 — Planning | Complete | `02-planning/` — POC architecture, shared-package strategy, Xcode decision |
| 4-6 — Pre-build prep | Complete | Captured inline in planning artefacts |
| 7-8 — POC build | Complete | 7 POCs (L1, L2, L3, L4, L5, L6, capstone). 92 tests passing across all POCs. Red/green/regression TDD trail per POC. |
| 9 — Quality gate | PASS | Evidence-auditor verdict on distillation: PASS. Zero unsupported claims. 12/12 sampled pointers verified. |
| 10 — Distillation | Complete | `05-distillation/` — 64 files. 296 evidence pointers. 79 cross-links. |
| 11 — Skill pack | Complete | `06-skill-pack/` — 70 files. All reachable from index.md. |
| 12 — Evaluation | This document | + intent-validator run in close-out |

## POC inventory

| Level | Slug | Tests | Audit trail (red/green/regression SHAs) | Built without Xcode? |
|-------|------|-------|----------------------------------------|----------------------|
| L1 | hello-spm | 4 | 79f9aa8 / 32c6790 / 78c91b2 | ✅ |
| L2 | anthropic-client | 33 | 53f5896 / 8574143 / efd0268 | ✅ |
| L3 | cli-chat | 15 | 5fe08e3 / d9a9c1b / 80e383d | ✅ |
| L4 | hummingbird-tool-service | 16 | 4d08b28 / fedc64d / cfcc99e | ✅ |
| L5 | swiftui-macos-app | 8 | dcf25a1 / d84c2f3 / ca441b0 | ✅ (compile only; window-launch unverified) |
| L6 | swiftui-ios-app | 7 | (combined commit 07a67cd repaired from nested-repo) | Library: ✅ Test: ✅ iOS app build: requires Xcode |
| L-capstone | multiplatform-chat | 9 | 8fdcbd0 / ad0c09d / db382ea | All 3 products compile under CLT; iOS app build requires Xcode |

**Total tests: 92, all passing.**

## What this degree delivers
- Typed Swift client for the Anthropic Messages API (sync + streaming), tested without network.
- Terminal chat CLI with multi-turn history, actor-isolated state, streaming output.
- Hummingbird 2.x HTTP service exposing the LLM as a tool surface, with SSE streaming endpoint.
- SwiftUI macOS chat client with `@Observable`/`@Bindable` view-model wiring.
- Multiplatform SwiftPM package (iOS + macOS) demonstrating cross-platform SwiftUI code reuse with `#if os(iOS)` guards.
- Unified capstone: shared library + backend + macOS app + iOS source files + Dockerfile + end-to-end integration test.
- 63 distilled artefacts (gotchas, patterns, anti-patterns, playbooks, before-you-build, decision records) — every claim cites evidence.
- 70-file skill pack with lessons, labs, recipes, troubleshooting, reference, examples, assessments, and LLM-agent instructions.

## Known caveats (gates that remain open)

1. **L5 windowed-app run NOT verified.** The L5 SwiftUI macOS app builds with Command Line Tools, but a research probe and the L5 worker only confirmed COMPILE — not that `swift run ChatMacApp` actually opens a window. A 60-second manual `swift run` check is the next item.
2. **L6 / capstone iOS app NOT built.** Xcode is not installed on the host machine. The iOS app source files in `iosApp/` are validated by static review and the shared library compiles for iOS via the multiplatform Package.swift, but the actual iOS app target build under `xcodebuild` is deferred. `OPEN-IN-XCODE.md` in L6 and capstone documents the steps.
3. **No real Anthropic API call has been made.** All POCs were tested against mocks. Smoke-testing the backend or CLI against a real API key (`ANTHROPIC_API_KEY=… swift run chat`) is the obvious next step.
4. **Capstone Dockerfile assumes a non-trivial build context.** The relative-path SwiftPM dependency on `../L2-anthropic-client` won't resolve in a vanilla `docker build` because that file isn't in the build context. The Dockerfile documents the production *shape*; a real production build needs either a monorepo Dockerfile at the parent or a Swift package registry. ADR-008 captures this trade-off.

## Recommended next steps (optional follow-ups, not blockers)

1. Install Xcode → open `L6-swiftui-ios-app/` per OPEN-IN-XCODE.md → run on iPhone Simulator.
2. Run `ANTHROPIC_API_KEY=… swift run chat` (L3) to validate end-to-end with real Claude.
3. Run `swift run ChatMacApp` (L5) to confirm a real SwiftUI window opens.
4. Promote a real publishable `ChatCore` package to a separate repo (decouple from sibling-path SwiftPM deps).

## GitHub
- Repo: https://github.com/dennisonbertram/agent-university-swift
- Branch: `main`
- All work pushed.

## Sign-off
Degree 01 (Swift Overview) is ready for use as a teaching artefact by LLM coding agents. Open caveats are documented and non-blocking for the educational use case.
