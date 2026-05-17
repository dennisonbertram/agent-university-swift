# L-capstone — multiplatform chat

Everything assembled. One SwiftPM package, three products:

- **ChatCore** (library) — cross-platform domain. ChatViewModel, ChatMessage, LLMService, BackendLLMService, HealthClient, SwiftUI views. iOS 17+ / macOS 14+.
- **chat-backend** (executable) — Hummingbird HTTP server. `/health`, `/chat`, `/chat/stream`. Talks to Anthropic upstream.
- **ChatMacApp** (executable) — SwiftUI macOS chat app. Talks to chat-backend by default (env `CHAT_BACKEND_URL`); falls back to direct Anthropic if `ANTHROPIC_API_KEY` is set.

Plus `iosApp/` — Xcode-ready iOS app source files. See `iosApp/OPEN-IN-XCODE.md`.

## Build everything

```bash
swift build      # all 3 products
swift test       # full test suite — no Anthropic API key required
```

## Run the backend

```bash
export ANTHROPIC_API_KEY=...
swift run chat-backend
# server on http://127.0.0.1:8080
```

## Run the macOS app, talking to the backend

```bash
export CHAT_BACKEND_URL=http://localhost:8080
swift run ChatMacApp
# window opens, chat works against your local backend
```

## Run the macOS app, talking to Anthropic directly

```bash
export ANTHROPIC_API_KEY=...
swift run ChatMacApp
```

## Dockerize the backend

```bash
docker build -t chat-backend .
docker run -p 8080:8080 -e ANTHROPIC_API_KEY=... chat-backend
```

> **Note:** See `Dockerfile` for caveats about the build context and the sibling `L2-anthropic-client` dependency.

## End-to-end test

`Tests/CapstoneTests/EndToEndTests.swift` proves the full chain: ChatViewModel → URLSession → Hummingbird → MockUpstream, with no Anthropic call. This is the integration story.

## Package structure

```
L-capstone-multiplatform-chat/
├── Package.swift              # Three products + ChatBackendLib (testable backend logic)
├── Sources/
│   ├── ChatCore/              # Cross-platform library: domain + views
│   │   ├── ChatViewModel.swift       # Observable, MainActor, no SwiftUI import
│   │   ├── BackendLLMService.swift   # URLSession SSE client → /chat/stream
│   │   ├── HealthClient.swift        # URLSession → /health
│   │   └── Views/                   # SwiftUI views (ChatScreen, MessageRow, InputBar)
│   ├── chat-backend/          # Hummingbird server + entry point
│   │   ├── BackendApp.swift          # buildBackend() factory
│   │   ├── Router.swift              # /health, /chat, /chat/stream handlers
│   │   └── main.swift                # top-level entry, reads ANTHROPIC_API_KEY
│   └── ChatMacApp/            # SwiftUI macOS app
├── iosApp/                    # Xcode-ready iOS source files
└── Tests/CapstoneTests/       # Integration + regression tests
```

## Architecture

```
ChatMacApp / iosApp
     │
     ▼
ChatCore (ChatViewModel)
     │
     ├── BackendLLMService ──── HTTP SSE ──► chat-backend ──► AnthropicClient (real)
     │                                                        MockUpstreamLLMService (tests)
     └── AnthropicClient (direct mode)
```

## Dependencies

- `../L2-anthropic-client` — the typed Anthropic client (sibling POC).
- `hummingbird` 2.x — Swift HTTP server.
