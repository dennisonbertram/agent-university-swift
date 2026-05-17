# POC Architecture — L1 through L-capstone

> Grounded in Phase 2 research. Cross-references:
> - L: see `01-research/01-language-and-concurrency.md`
> - T: `02-swiftpm-and-tooling.md`
> - A: `03-anthropic-api-in-swift.md`
> - H: `04-hummingbird.md`
> - U: `05-swiftui-multiplatform.md`
> - G: `06-expectation-gaps.md`

Each POC progression adds **one** new concept and consumes prior POCs as SwiftPM dependencies via relative-path `.package(path: "../LN-...")`. No code is copy-pasted between POC roots — sharing is enforced through the package graph so a regression in L2 surfaces immediately in L3+.

Anthropic model id pinned across POCs: `claude-sonnet-4-5` (default), preferring dated variant `claude-sonnet-4-5-20250929` where reproducibility matters. Anthropic version header pinned to `2023-06-01`. Source: A §3.

---

## L1 — `L1-hello-spm`

**Goal**: Establish a minimal SwiftPM executable + library + test-target layout with swift-testing and prove the toolchain works end-to-end.

**New concept**: SwiftPM project structure, `swift build` / `swift run` / `swift test`, `@Test` macro from `import Testing`, `platforms:` declaration.

**File layout**:
```
L1-hello-spm/
├── Package.swift
├── README.md
├── Sources/
│   ├── HelloCore/                 ← library target
│   │   └── Greeter.swift
│   └── hello/                     ← executable target
│       └── main.swift
└── Tests/
    └── HelloCoreTests/
        └── GreeterTests.swift
```

**Behavioral tests** (TDD red commit):
1. When `Greeter.greet(name: "world")` is called, then it returns `"Hello, world!"`.
2. When `Greeter.greet(name: "")` is called, then it returns `"Hello, friend!"` (empty-name fallback).
3. When `swift run hello Ada` is executed, then stdout is `Hello, Ada!\n` and exit code is 0.
4. When `swift run hello` is executed with no args, then stdout is `Hello, friend!\n` and exit code is 0.
5. When `swift test` is run, then the test summary contains `Test run with 2 tests passed`.

**Dependencies on prior POCs**: none (root of progression).

**External dependencies**: none. swift-testing is bundled with Swift 6 — no `dependencies:` array entry required (T §6, G EG-08).

**Acceptance**:
- `swift build` exits 0.
- `swift run hello Ada` prints `Hello, Ada!`.
- `swift test` reports all tests passing under the `Testing` library.

**Known risks**:
- *`swift package init` does not emit `platforms:`* (G EG-02). Mitigation: scaffold Package.swift by hand from the template in T §1; never trust `swift package init` output verbatim.
- *Two entry points* (`main.swift` + `@main` struct) is a compile error (T §4). Mitigation: pick `main.swift`-only at L1 because no argument parsing yet. `@main` shows up at L3 with `AsyncParsableCommand`.

---

## L2 — `L2-anthropic-client`

**Goal**: Ship a typed, testable, Sendable-clean Anthropic Messages API client (non-streaming first) as a SwiftPM library, with no external runtime dependencies beyond Foundation.

**New concept**: Library target shaped for downstream consumption, `Codable` JSON modelling, `actor` for thread-safe state, `URLSession` async APIs, custom `Error` enum, dependency injection via protocol for testability.

**File layout**:
```
L2-anthropic-client/
├── Package.swift
├── README.md
├── Sources/
│   └── AnthropicClient/
│       ├── AnthropicClient.swift          ← actor; public API
│       ├── Models/
│       │   ├── MessagesRequest.swift      ← Encodable (A §7)
│       │   ├── MessagesResponse.swift     ← Decodable (A §7)
│       │   ├── Message.swift              ← role + MessageContent
│       │   ├── ContentBlock.swift
│       │   ├── Tool.swift                 ← Tool, JSONSchema, ToolChoice
│       │   └── Usage.swift
│       ├── Errors.swift                   ← AnthropicError enum (A §8)
│       └── HTTPTransport.swift            ← protocol for URLSession injection
└── Tests/
    └── AnthropicClientTests/
        ├── EncodingTests.swift            ← golden JSON snapshots
        ├── DecodingTests.swift            ← canned response decoding
        ├── ErrorMappingTests.swift        ← 401/429/529/4xx mapping
        └── Fixtures/
            └── messages-response.json
```

**Behavioral tests**:
1. When a `MessagesRequest(model: "claude-sonnet-4-5", messages: [.user("hi")], maxTokens: 1024)` is encoded, then the JSON key `max_tokens` exists (not `maxTokens`) and equals 1024.
2. When a `MessagesRequest` with `tools: nil` is encoded, then no `tools` key appears in output (Encodable omits nil — verify explicitly).
3. When the fixture `messages-response.json` is decoded, then `response.content.first?.text == "Hi! My name is Claude."` and `response.usage.outputTokens == 25`.
4. When the transport returns HTTP 401, then `client.send(...)` throws `AnthropicError.unauthorized`.
5. When the transport returns HTTP 529, then `client.send(...)` throws `AnthropicError.overloaded` (Anthropic-specific status — G implicit, A §10 FM-5).
6. When `ANTHROPIC_API_KEY` is unset and the default initializer is used, then the constructed `URLRequest` carries an empty `x-api-key` header (caller can detect and refuse to send).

**Dependencies on prior POCs**: L1's `HelloCore` is NOT consumed (different domain). L1 establishes the workflow; L2 is independently rooted but follows the same Package.swift conventions.

**External dependencies**: none (Foundation only — `URLSession`, `JSONEncoder`, `JSONDecoder`).

**Acceptance**:
- `swift build` exits 0.
- `swift test` passes all 6 behavioral tests using a mocked `HTTPTransport` (no live API calls).
- Optional manual smoke: `ANTHROPIC_API_KEY=... swift run` of a tiny example calling the client returns a real response. Manual only — not in CI.

**Known risks**:
- *MessageContent dual-shape (string vs array)*: Anthropic accepts `"content": "hi"` or `"content": [{type:"text",...}]`. Mitigation: implement `MessageContent` as the dual-shape enum from A §7 with custom `init(from:)` / `encode(to:)`; cover both shapes in EncodingTests.
- *`max_tokens` required* (A top-fact #10): Mitigation: model it as non-optional `Int` in `MessagesRequest`; the type system enforces it.
- *Sendable across actor*: `URLSession.shared.data(for:)` returns `Sendable` already; custom transport protocol must declare `Sendable` requirement (L §3) to keep the actor Sendable-clean.

---

## L3 — `L3-cli-chat`

**Goal**: A streaming CLI chat tool. User types, model streams back tokens live to stdout. Demonstrates SSE parsing, structured concurrency, cancellation on Ctrl-C, and argument parsing.

**New concept**: `AsyncThrowingStream`, SSE event parsing (`event: message_stop` not `data: [DONE]` — G EG-05, EG-13), `AsyncParsableCommand`, `@Argument`/`@Option`/`@Flag`, `Task` cancellation propagation.

**File layout**:
```
L3-cli-chat/
├── Package.swift
├── README.md
├── Sources/
│   └── chat/
│       ├── Chat.swift                     ← @main AsyncParsableCommand
│       ├── StreamingExtension.swift       ← extends AnthropicClient with .stream(_:)
│       └── SSEParser.swift                ← line-by-line event accumulator
└── Tests/
    └── chatTests/
        ├── SSEParserTests.swift           ← fixtures: ping/delta/stop
        └── Fixtures/
            ├── stream-happy.txt           ← canned SSE bytes
            ├── stream-with-ping.txt
            └── stream-truncated.txt
```

**Behavioral tests**:
1. When the SSE fixture `stream-happy.txt` is fed line-by-line into the parser, then the parser yields `content_block_delta` events with concatenated text `"Hi! My name is Claude."` and finishes on `message_stop`.
2. When `stream-with-ping.txt` includes `event: ping` lines, then the parser ignores them (does NOT yield) and completes normally (G EG-13).
3. When `stream-truncated.txt` cuts off mid-stream, then the parser's `AsyncThrowingStream` throws `AnthropicError.sseParseError` (not silently completes).
4. When `swift run chat --help` is run, then it lists `--model`, `--max-tokens`, and `--system` options and shows the positional `<prompt>` argument.
5. When the user sends SIGINT during streaming, then the `Task` is cancelled, the SSE iterator terminates, and exit code is 130 (128 + SIGINT).

**Dependencies on prior POCs**:
- L2 consumed via `.package(path: "../L2-anthropic-client")` and `.product(name: "AnthropicClient", package: "L2-anthropic-client")`. The streaming extension lives in L3 to keep L2's surface minimal; alternatively L3 can promote streaming back into L2 once the API stabilizes (decision deferred to log).

**External dependencies**: `swift-argument-parser` `1.5.0+` (we will pin `from: "1.5.0"` — verified 1.7.1 ships compatibly per T §7).

**Acceptance**:
- `swift build` exits 0.
- `swift test` all SSE parser tests pass.
- Manual smoke: `ANTHROPIC_API_KEY=... swift run chat "What is 2+2?"` prints streaming tokens to stdout ending in a newline, exits 0.
- `swift run chat --help` shows the subcommand-free help text with all options documented.

**Known risks**:
- *SSE line buffering*: `URLSession.AsyncBytes.lines` yields once per `\n`. SSE allows `\r\n` and blank-line event separators (A §5). Mitigation: parser must handle both line endings and reset event-type state on blank lines.
- *Cancellation cleanup*: an actor-owned `AsyncThrowingStream` needs `continuation.onTermination` to cancel the in-flight URL task (A §8). Mitigation: explicit `onTermination` handler; covered by test #5 sketch.
- *AsyncParsableCommand + @main + main.swift collision*: do NOT include a `main.swift` in this target (T §9 FM-3). The struct is named `Chat` in `Chat.swift`.

---

## L4 — `L4-hummingbird-tool-service`

**Goal**: An HTTP service that exposes the L2 Anthropic client as JSON endpoints — both non-streaming (`POST /chat`) and streaming (`POST /chat/stream` with SSE response). Demonstrates Hummingbird 2.x routing, middleware, `ResponseCodable`, and request decoding.

**New concept**: Hummingbird 2.x `Router` + `Application` + `runService()` (H §3), `RouterMiddleware`, JSON request/response handling, server-side SSE re-emission, `swift-log` structured logging via context.

**File layout**:
```
L4-hummingbird-tool-service/
├── Package.swift
├── README.md
├── Sources/
│   └── tool-service/
│       ├── App.swift                       ← @main AsyncParsableCommand → starts HB
│       ├── Routes/
│       │   ├── ChatRoute.swift             ← POST /chat
│       │   └── ChatStreamRoute.swift       ← POST /chat/stream
│       ├── Middleware/
│       │   └── AuthMiddleware.swift        ← Bearer token check (env)
│       └── DTOs.swift                      ← ChatRequest, ChatResponse: Codable, ResponseCodable
└── Tests/
    └── tool-serviceTests/
        ├── ChatRouteTests.swift            ← HummingbirdTesting in-process
        └── AuthMiddlewareTests.swift
```

**Behavioral tests**:
1. When `POST /chat` receives `{"prompt":"hi","model":"claude-sonnet-4-5"}` with valid Bearer token, then the response status is 200 and body decodes as `{"reply":"<assistant text>","usage":{...}}`.
2. When `POST /chat` receives a request with an Authorization header missing the Bearer token, then response status is 401 and no Anthropic call is made (verified with mock client).
3. When `POST /chat/stream` is called with a valid body, then the response `content-type` is `text/event-stream` and the body re-emits Anthropic SSE events line-for-line, terminating on `event: message_stop`.
4. When `POST /chat` receives malformed JSON (missing `prompt`), then status is 400 and body contains an error message (no crash).
5. When the service is started with `LOG_LEVEL=debug`, then handler logs include `path=/chat` metadata at debug level (H §8).

**Dependencies on prior POCs**:
- L2 via `.package(path: "../L2-anthropic-client")`.
- L3's `SSEParser` is **not** reused server-side (we re-emit upstream bytes rather than re-parse). Stream wiring uses raw passthrough.

**External dependencies**:
- `hummingbird` `2.23.0+` (`from: "2.0.0"` semver bound — verified at 2.23.0 in H §1).
- `swift-argument-parser` `1.5.0+`.

**Acceptance**:
- `swift build` exits 0.
- `swift test` passes using `HummingbirdTesting` in-process client (H §9) — no real Anthropic calls (mock transport injected).
- Manual smoke: `ANTHROPIC_API_KEY=... swift run tool-service --port 8080`, then:
  - `curl -H "Authorization: Bearer dev" -d '{"prompt":"hi"}' http://127.0.0.1:8080/chat` returns JSON 200.
  - `curl -N -H "Authorization: Bearer dev" -d '{"prompt":"count to 3"}' http://127.0.0.1:8080/chat/stream` streams SSE lines.
- Graceful shutdown: `kill -TERM <pid>` drains and exits 0 within 5s (H §9, `runService()`).

**Known risks**:
- *Middleware ordering* (H §7, FM-6): `router.middlewares.add(AuthMiddleware())` must execute BEFORE route registration; verified by test #2.
- *SSE re-emit*: writing `text/event-stream` from a Hummingbird handler requires a streaming `ResponseBody`. Mitigation: use `Response(status: .ok, headers: [.contentType: "text/event-stream"], body: .init { writer in ... })` pattern; document the exact API used after building L4 since this corner of HB is less covered in research.
- *Port collision* (H §12 FM-1): make port a CLI arg with default 8080; pre-flight check optional.

---

## L5 — `L5-swiftui-macos-app`

**Goal**: A macOS SwiftUI chat app that consumes L2's `AnthropicClient` and renders streaming responses live in a list view.

**New concept**: `@main struct App: App`, `WindowGroup`, `Scene`, `@Observable` view model on `@MainActor`, `.task { }` modifier, streaming UI updates from `AsyncThrowingStream`.

**File layout**:
```
L5-swiftui-macos-app/
├── Package.swift                          ← executable target, platforms: [.macOS(.v15)]
├── README.md
└── Sources/
    └── ChatMac/
        ├── ChatMacApp.swift               ← @main App, WindowGroup, Settings scene
        ├── Views/
        │   ├── ContentView.swift          ← root view, list + input
        │   ├── MessageRow.swift
        │   └── InputBar.swift             ← TextField + Send button
        └── ViewModels/
            └── ChatViewModel.swift        ← @Observable @MainActor, owns AnthropicClient
```

**Behavioral tests**:
SwiftUI rendering tests with snapshots are out of scope for L5 (Xcode-only territory). L5 ships unit tests for the view model logic:

1. When `ChatViewModel.send(prompt: "hi")` is called and the mock client streams 3 text deltas, then `viewModel.currentAssistantText` ends with the concatenated deltas and `viewModel.isStreaming == false` after completion.
2. When `send` is called while `isStreaming == true`, then the prior task is cancelled before the new one starts (no two streams concurrent).
3. When the mock client throws `AnthropicError.unauthorized` mid-stream, then `viewModel.lastError != nil` and `viewModel.isStreaming == false`.
4. When `viewModel.messages` is mutated, then it happens on `MainActor` (verified by `MainActor.assertIsolated()` in test).

UI behaviors are documented as manual smoke checks rather than automated:
- M1. App launches, shows empty message list and an input bar.
- M2. Typing in the field and pressing Cmd-Return submits the prompt; the assistant message streams in token by token.

**Dependencies on prior POCs**:
- L2 via `.package(path: "../L2-anthropic-client")` and `.product(name: "AnthropicClient", package: "L2-anthropic-client")`.
- L3 NOT consumed directly. The streaming extension is duplicated here (small, ~30 lines) OR promoted into L2 — decided in L3's risk note. If promoted, L5 just imports `AnthropicClient`.

**External dependencies**: none beyond L2.

**Acceptance**:
- `swift build` exits 0 with CLT-only toolchain (verified possible — U §1, §8).
- `swift test` view-model tests pass.
- Manual run: `swift run ChatMac` launches a window (see `02-xcode-decision.md` for the verification step that this actually works without Xcode).
- Screenshot in README showing the chat UI with a streamed response.

**Known risks**:
- *CLT-only run uncertainty* (G EG-07): SwiftUI macOS compiles with CLT, but **running** a windowed app from `swift run` may or may not work without an `.app` bundle and Info.plist. Mitigation: documented and tested in `02-xcode-decision.md`; if it fails, fall back to manual `xcodebuild` build.
- *MainActor discipline*: streaming deltas arrive on background threads. Mitigation: mark `ChatViewModel` `@MainActor` (U §4 pattern); all mutations safe.
- *`@Observable` deployment target*: requires macOS 14+. Mitigation: `Package.swift` already pins `.macOS(.v15)`.

---

## L6 — `L6-swiftui-ios-app`

**Goal**: An iOS port of L5 that proves the chat-domain code (view model, client, types) is genuinely shared. The iOS-specific code is only the SwiftUI view shell + iOS conveniences (`NavigationStack`, keyboard avoidance).

**New concept**: Cross-platform code sharing through a multiplatform SwiftPM package (see `01-shared-package-strategy.md`), `NavigationStack` (U §6), iOS keyboard-safe input bar (U §11), Xcode project that adds the local Swift package as a dependency.

**File layout**:
```
L6-swiftui-ios-app/
├── README.md
├── ChatiOS.xcodeproj/                     ← MUST be Xcode; iOS targets need it
├── ChatiOS/
│   ├── ChatiOSApp.swift                   ← @main App; iOS WindowGroup only
│   ├── Views/
│   │   ├── ChatScreen.swift               ← NavigationStack + ScrollView
│   │   └── InputBar.swift                 ← .safeAreaInset for keyboard avoidance
│   └── Info.plist                         ← iOS-specific
└── (Shared code lives in L2 or the multiplatform package — NOT duplicated here.)
```

**Behavioral tests**:
1. When `ChatViewModel` (imported from the shared package) is exercised in iOS unit tests, then the same tests that passed in L5 pass here unchanged.
2. When the iOS app launches in the simulator, then it shows the chat screen with a keyboard-aware input bar (manual smoke).
3. When the user rotates the device, then layout adapts without truncation (manual smoke).

**Dependencies on prior POCs**:
- L2 (`AnthropicClient`) via "Add Package Dependencies" in Xcode pointing to `../L2-anthropic-client` local path.
- L5's `ChatViewModel` is shared either by: (a) promoting it into a new shared package (preferred — see `01-shared-package-strategy.md`); or (b) consuming L5 as a package too. The strategy doc recommends (a).

**External dependencies**: none beyond L2 / shared package.

**Acceptance**:
- Project opens in Xcode 16.3+ without errors.
- `xcodebuild -scheme ChatiOS -destination 'platform=iOS Simulator,name=iPhone 15'` builds successfully.
- Manual run in simulator: streaming chat works.
- Screenshot in README.

**Known risks**:
- *Xcode required* (U §8): iOS simulator and signing infrastructure are not available in CLT. Mitigation: gate L6 behind a confirmed Xcode install (decision in `02-xcode-decision.md`).
- *Shared-package consumption*: Xcode and SwiftPM CLI must agree on `Package.resolved`. Mitigation: commit `Package.resolved`; both tools read the same file.
- *Keyboard avoidance regressions*: `.ignoresSafeArea(.keyboard)` and `.safeAreaInset` behavior shifted in iOS 17 (U §11). Mitigation: pin `.iOS(.v18)`.

---

## L-capstone — `L-capstone-multiplatform-chat`

**Goal**: A unified project that wires together everything: a shared core package + macOS shell + iOS shell + Hummingbird backend (optional proxy mode). Demonstrates full reuse, tests on all platforms, and a Dockerfile for the backend.

**New concept**: Integration. No new framework or language feature — the value is in assembling the parts into something a real engineer would ship.

**File layout**:
```
L-capstone-multiplatform-chat/
├── Package.swift                          ← multiplatform: macOS + iOS
├── README.md
├── Dockerfile                             ← server image (Swift slim base)
├── Sources/
│   ├── ChatCore/                          ← shared: client + view model + types
│   ├── ChatBackend/                       ← Hummingbird executable (proxy mode)
│   ├── ChatMacApp/                        ← @main, macOS app shell
│   └── ChatiOSApp-supporting/             ← .swift files imported by Xcode iOS target
├── ChatiOS.xcodeproj/                     ← iOS app shell (Xcode project)
└── Tests/
    ├── ChatCoreTests/
    └── ChatBackendTests/
```

**Behavioral tests**:
1. When `swift test` is run at repo root, then ChatCore tests AND ChatBackend tests both run and pass.
2. When `docker build -t chat-backend . && docker run --rm -e ANTHROPIC_API_KEY=$KEY -p 8080:8080 chat-backend` is executed, then `curl http://localhost:8080/chat` works.
3. When ChatMacApp connects to the local backend (instead of Anthropic direct), then streaming still works (proxy-mode end-to-end).
4. When ChatiOSApp is built for the simulator, then it links against the same ChatCore module as the macOS app (verified by build log).
5. When the user runs `make test`, then it executes `swift test` and then `xcodebuild test` for the iOS target.

**Dependencies on prior POCs**:
- L2: AnthropicClient lives inside ChatCore (promoted from L2 as a path dep, or vendored as source — decision in 01-shared-package-strategy.md).
- L3's CLI streaming logic is folded into ChatCore.
- L4's Hummingbird routes become ChatBackend.
- L5/L6's view models become ChatCore view models.

**External dependencies**:
- `hummingbird` 2.23.0+, `swift-argument-parser` 1.5.0+, `swift-log` (transitively via Hummingbird).

**Acceptance**:
- `swift test` exits 0.
- `docker build` succeeds and image runs.
- macOS app launches, iOS app builds in simulator.
- All tests from prior levels still pass when their code is consumed through ChatCore.

**Known risks**:
- *Module name collisions*: if L2 and ChatCore both export `AnthropicClient`, they cannot both be in the same dependency graph. Mitigation: capstone consumes ONLY ChatCore; L2 is the source for ChatCore but not a separate consumed package at this level.
- *Docker image size and Swift static linking*: choose `swift:6.1-slim` base; the produced binary will be ~80MB. Mitigation: multi-stage Dockerfile.
- *iOS + SwiftPM project integration*: Xcode and SwiftPM CLI behave differently around `Package.resolved` and target membership. Mitigation: keep ChatiOS as an Xcode project that adds the multiplatform package; do not try to drive iOS builds from `swift build`.
