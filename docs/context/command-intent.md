# Command Intent — Agent University: Swift

## Verbatim user request

> Read /Users/dennison/develop/agent-university/start-degree.md and do it for Swift

The user issued this as a `/goal` directive and authorized the coordinator to "go with your recommendations" after the coordinator outlined scope options.

## Interpreted intent

Execute the agent-university `start-degree.md` protocol end-to-end for the topic "Swift", producing a structured, LLM-agent-targeted "degree" repository containing research, progressive POCs, distilled knowledge, a skill pack, and a readiness assessment.

## Success criteria

1. A repository exists at `/Users/dennison/develop/agent-university/swift/`, mirrored to GitHub at `dennisonbertram/agent-university-swift`.
2. The 12-phase doctrine in `/Users/dennison/develop/agent-university/instructions/instructions.md` is honored — every quality gate is run (evidence-auditor) and the intent-validator runs foreground before close.
3. Six POC levels are built, tested, and committed (L1–L5 plus capstone).
4. Distilled artifacts (gotchas, patterns, anti-patterns, playbooks, before-you-build, decision-records) exist with **evidence pointers for every claim**.
5. A skill pack exists with an index.md from which every other file is reachable; no orphan files, no broken links.
6. `degrees/01-swift-overview/07-evaluation/readiness.md` is filled and signed off.

## User's mental model

The user expects a self-contained Swift "degree" matching the structure of `bun-data-stack/` and `mastra-ai/` precedents — i.e., a recipe an LLM agent could consume to bootstrap real Swift work.

## Assumptions (subject to correction)

- Audience is LLM agents, not human readers. Artifacts are explicit and structured, not narrative.
- Scope is server-side / CLI Swift, because the host machine only has Swift Command Line Tools (no full Xcode). SwiftUI/UIKit/iOS app development is explicitly out of scope.
- POC progression is six levels: L1 hello-spm → L2 library-with-protocols → L3 cli-argparse → L4 concurrency-actors → L5 http-service (Hummingbird) → L-capstone agent-tool-service.
- HTTP framework choice at L5/capstone: Hummingbird (leaner and async-first compared to Vapor; better fit for an agent-tool service).
- Version pin: Swift 6.1.2 (the version installed locally — swiftlang-6.1.2.1.2 on arm64-apple-macosx15.0).
- GitHub repo is public, named `agent-university-swift`.

## Out of scope (explicit)

- SwiftUI, UIKit, iOS app shells, watchOS, tvOS, visionOS.
- Xcode project files; this degree uses SwiftPM exclusively.
- Distributed actors clustering / swift-distributed-actors.
- Embedded Swift.
- Apple-private frameworks.
- Vapor (Hummingbird was chosen; Vapor may be referenced for comparison but no Vapor POC is built).

## Open questions / risks

- Hummingbird vs Vapor: Hummingbird chosen. Researcher may surface a reason to revisit at Phase 2.
- The host machine has Swift 6.1.2; the researcher should confirm whether Swift 6.2 / 6.3 introduces material changes worth noting in the source-inventory.

## Scope amendment — LLM + iOS + macOS UI

After the coordinator presented Option D (server/CLI only) and the user approved it, the user added: *"go with your recommendations but include using an LLM in swift and making a front end for iphone and for desktop os."*

Therefore three new domains are added to scope:

1. **Using an LLM from Swift.** Specifically a typed Anthropic API client (sync + streaming) as a SwiftPM library — the shared core that every higher-level POC depends on.
2. **macOS desktop frontend** using SwiftUI for macOS — a native chat UI that uses the shared LLM client.
3. **iOS / iPhone frontend** using SwiftUI for iOS — same chat UI, sharing the LLM client via a SwiftPM package, demonstrating multiplatform code reuse.

## Xcode constraint (acknowledged)

The host machine only has Swift Command Line Tools, not full Xcode. iOS simulator builds and SwiftUI previews require full Xcode. The coordinator will scaffold the UI POCs (L5/L6/L-capstone) so they are build-ready and ship with a documented "Install Xcode to verify" gate. macOS-only SwiftUI may partially work with CLT — researcher will confirm in Phase 2.

## Revised POC progression

| Level | POC slug | Concept introduced | Xcode required to build? |
|-------|----------|--------------------|--------------------------|
| L1 | `L1-hello-spm` | SwiftPM + swift-testing | No |
| L2 | `L2-anthropic-client` | Library design, Anthropic API, Codable, error handling | No |
| L3 | `L3-cli-chat` | swift-argument-parser, async streaming, actors, Sendable | No |
| L4 | `L4-hummingbird-tool-service` | HTTP service exposing LLM tool surface | No |
| L5 | `L5-swiftui-macos-app` | SwiftUI macOS, app lifecycle, state management | Yes (likely) |
| L6 | `L6-swiftui-ios-app` | SwiftUI iOS, target sharing via SwiftPM, multiplatform code reuse | Yes |
| L-capstone | `L-capstone-multiplatform-chat` | All combined: shared core + macOS app + iOS app + Hummingbird backend | Yes |
