# Swift Degree — Phase 2 Research Index

**Toolchain**: Apple Swift 6.1.2 (swiftlang-6.1.2.1.2, clang-1700.0.13.5), arm64-apple-macosx15.0  
**Research date**: 2026-05-16  
**Method**: ctx7 (quota exceeded, fallback to WebFetch), WebFetch, WebSearch, 6 runtime probes

---

## Executive Summary

This corpus covers the full Swift stack needed to build L1–L6 POC progression: SwiftPM packages, Anthropic API client, CLI tools, Hummingbird 2.x HTTP service, and SwiftUI multiplatform apps. The research was conducted against the live toolchain (Swift 6.1.2 on macOS 15), confirmed with 6 runtime probes, and cross-referenced against official GitHub sources.

**Top-line finding**: Swift 6 is a meaningful breaking change from Swift 5. Global mutable state, Sendable violations, and existential types all become hard compile errors. LLM training data predominantly describes Swift 5 patterns. This is the single largest category of mistakes an LLM agent will make when generating Swift code for this stack.

**Second top-line finding**: Hummingbird 1.x and 2.x are completely incompatible. Every LLM trained on data before mid-2024 will generate Hummingbird 1.x code (`HBApplication`, `HBRequest`, NIO futures) that does not compile against 2.x.

**Third top-line finding**: No official Anthropic Swift SDK exists. All community SDKs are pre-1.0 and low-star. The recommended approach for this POC is a ~100-line bespoke client using URLSession + Codable + AsyncThrowingStream.

---

## Top 10 Load-Bearing Facts

1. **Swift 6 global mutable state is a compile error** — `var x = 0` at file scope is `error: nonisolated global shared mutable state`. Requires `let`, `@MainActor`, actor encapsulation, or `nonisolated(unsafe)`.

2. **Always add `platforms:` to Package.swift** — `swift package init` does NOT generate it. Without `platforms: [.macOS(.v15)]`, swift-testing's `@Test` macro fails with `'isolation()' is only available in macOS 10.15 or newer`.

3. **Hummingbird 2.x API**: `let router = Router(); router.get("path") { req, ctx in ... }; Application(router: router)`. No `HB` prefix. Handlers are `async throws`. This is completely different from v1.

4. **Anthropic SSE streams end with `event: message_stop`, NOT `data: [DONE]`** — handle `ping` events (ignore them), accumulate `text_delta` events, finish on `message_stop`.

5. **No official Anthropic Swift SDK** — build a bespoke client using URLSession async APIs + Codable + AsyncThrowingStream. The client fits in ~150 lines.

6. **`@Observable` macro (Swift 5.9+) replaces `ObservableObject`** — no `@Published`, no `@StateObject`, no `@ObservedObject`. Use `@State var vm = ViewModel()` to own it, pass as `var vm: ViewModel` to children.

7. **swift-testing is bundled with Swift 6 — no Package.swift dependency needed** — `import Testing` works as-is. Tests run in parallel by default (unlike XCTest).

8. **AsyncThrowingStream is the idiom for SSE parsing** — `URLSession.shared.bytes(for:)` returns `URLSession.AsyncBytes`; iterate `.lines` to parse SSE line-by-line. This is the correct Swift 6 pattern.

9. **SwiftUI compiles with CLT only on macOS 15** — but cannot run or sign apps without full Xcode. CLT-only `swift build` works for type-checking SwiftUI code.

10. **`max_tokens` is required in every Anthropic Messages API request** — it is NOT optional. The Swift struct must have a non-optional `maxTokens: Int`.

---

## Top 10 Expectation Gaps

1. **Swift 5 concurrency warnings are Swift 6 errors** — see `06-expectation-gaps.md` EG-01
2. **`swift package init` generates an incomplete Package.swift** (no platforms) — EG-02
3. **Hummingbird 1.x syntax is completely wrong for 2.x** — EG-03
4. **`@Observable` replaces `ObservableObject`** — EG-04
5. **Anthropic SSE does not use `data: [DONE]`** — EG-05
6. **No official Anthropic Swift SDK exists** — EG-06
7. **SwiftUI compiles with CLT-only (but cannot run)** — EG-07
8. **swift-testing needs no Package.swift dependency** — EG-08
9. **Non-Sendable crossing actors doesn't always error** (region-based isolation is more permissive) — EG-10
10. **`ping` SSE events must be handled explicitly** — EG-13

Full analysis with evidence: see `06-expectation-gaps.md`.

---

## Cross-Cutting Failure Modes

### Concurrency / Build

| Failure | Error | Fix |
|---------|-------|-----|
| Global mutable var | `nonisolated global shared mutable state` | `let`, `@MainActor`, or actor |
| Missing `platforms:` | `'isolation()' is only available in macOS 10.15 or newer` | Add `platforms: [.macOS(.v15)]` |
| Two entry points (`main.swift` + `@main`) | `'main' attribute cannot be used in a module that contains top-level code` | Pick one |
| Non-async `run()` in `ParsableCommand` | type error | Use `AsyncParsableCommand` |

### Auth / API

| Failure | Symptom | Fix |
|---------|---------|-----|
| Missing `ANTHROPIC_API_KEY` | HTTP 401 | Set env var |
| Invalid model ID | HTTP 400 | Use exact model string from docs |
| Missing `max_tokens` | HTTP 400 | Always include in request |
| Rate limit | HTTP 429 | Exponential backoff |
| Overload (Anthropic-specific) | HTTP 529 | Backoff and retry |

### Hummingbird

| Failure | Symptom | Fix |
|---------|---------|-----|
| Port in use | `bind(): Address already in use` | Kill process on port or change port |
| Blocking sync in handler | Event loop starvation | Use async APIs |
| Wrong Hummingbird version | `HBRequest`/`HBApplication` not found | Migrate to 2.x API |
| Middleware order | Routes not protected | Add middleware BEFORE registering routes |

### Platform / Toolchain

| Failure | Symptom | Fix |
|---------|---------|-----|
| iOS build without Xcode | Build error | Requires Xcode + simulator |
| SwiftUI preview without Xcode | Preview unavailable | Use Xcode |
| Entitlement missing | Network denied at runtime | Add `com.apple.security.network.client` |

---

## Reading Order

1. **`01-language-and-concurrency.md`** — Read first. All Swift code in this stack depends on the concurrency model. Swift 6 strictness is the foundation.

2. **`02-swiftpm-and-tooling.md`** — Read second. Every POC starts with a Package.swift. Covers init, build, test workflow, swift-testing, swift-argument-parser.

3. **`03-anthropic-api-in-swift.md`** — Core dependency for L2–L6. Messages API shape, SSE streaming, complete Codable types, recommended client architecture.

4. **`04-hummingbird.md`** — Needed for L4. Router, Application, middleware, JSON, graceful shutdown. Read after L2 client is clear.

5. **`05-swiftui-multiplatform.md`** — Needed for L5/L6. App lifecycle, @Observable, async tasks in views, shared package structure.

6. **`06-expectation-gaps.md`** — Read anytime. Consult when debugging unexpected compile errors or API mismatches.

---

## Sources Inventory

### Runtime Probes

| Probe | Command | Exit | Key Finding |
|-------|---------|------|-------------|
| `/tmp/swift-research-probe/hello-spm/` | `swift package init --type executable && swift build` | 0 | Generates swift-tools-version:6.1, no platforms |
| `/tmp/swift-research-probe/lib-test/` | `swift package init --type library && swift test` | 1→0 | platform missing breaks swift-testing; fixed with platforms: |
| `/tmp/swift-research-probe/actor-test/` | `swift build && .build/debug/actor-test` | 0 | actor + TaskGroup + AsyncThrowingStream work |
| `/tmp/swift-research-probe/global-state-test/` | `swift build` | 1 | Exact Swift 6 global mutable state error message |
| `/tmp/swift-research-probe/argparse-test/` | `swift build` | 0 | AsyncParsableCommand with @Argument @Option @Flag |
| `/tmp/swift-research-probe/hb-test/` | `swift build` | 0 | Hummingbird 2.23.0, Router, JSON routes, ResponseCodable |
| `/tmp/swift-research-probe/swiftui-test/` | `swift build` | 0 | SwiftUI compiles with CLT-only toolchain |

### Web Sources

| URL | Credibility | Used In |
|-----|-------------|---------|
| https://platform.claude.com/docs/en/api/messages | Official | 03 |
| https://platform.claude.com/docs/en/api/messages-streaming | Official | 03 |
| https://github.com/hummingbird-project/hummingbird | Official (vendor) | 04 |
| https://github.com/hummingbird-project/hummingbird-examples | Official (vendor) | 04 |
| https://hummingbird.codes/ | Official (vendor) | 04 |
| https://github.com/apple/swift-argument-parser | Official (Apple) | 02 |
| https://github.com/apple/swift-testing | Official (Apple) | 02 |
| https://developer.apple.com/documentation/swiftui/app-organization | Official (Apple) | 05 |
| https://github.com/fumito-ito/AnthropicSwiftSDK | Community | 03 |
| https://github.com/GeorgeLyon/SwiftClaude | Community | 03 |
| GitHub API: anthropics org repos | Inferred | 03 |
| GitHub search: anthropic swift sdk | Community | 03 |

### ctx7

ctx7 monthly quota was exceeded. All documentation was retrieved via WebFetch and WebSearch. Noted in unresolved questions.
