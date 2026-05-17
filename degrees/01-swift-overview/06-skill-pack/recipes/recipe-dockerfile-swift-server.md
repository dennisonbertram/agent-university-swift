# Recipe — Multi-Stage Dockerfile for a Hummingbird Swift Server

[Back to index](../index.md) | See also: [lesson-11-dockerizing-a-swift-server.md](../lessons/lesson-11-dockerizing-a-swift-server.md) | Playbook: `playbooks/playbook-dockerize-swift-server.md`

## Use this when

You want to containerise a Hummingbird backend for deployment.

## Dockerfile

```dockerfile
# Dockerfile — multi-stage production image for chat-backend
#
# NOTE on build context: this Dockerfile assumes the sibling package
# ../L2-anthropic-client is available in the build context.
# In a real production deployment you would either:
#   a) Copy L2-anthropic-client into the build context alongside this package, or
#   b) Publish L2-anthropic-client to a git URL and switch .package(path:) to .package(url:)

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM swift:6.1-jammy AS builder
WORKDIR /build

# Copy both packages into the build context
COPY . ./L-capstone-multiplatform-chat/
# Uncomment and adjust if L2 is a sibling package:
# COPY ../L2-anthropic-client ./L2-anthropic-client/

WORKDIR /build/L-capstone-multiplatform-chat
RUN swift build -c release --product chat-backend --static-swift-stdlib

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM swift:6.1-jammy-slim
WORKDIR /app
COPY --from=builder \
     /build/L-capstone-multiplatform-chat/.build/release/chat-backend \
     /app/chat-backend

EXPOSE 8080
ENV PORT=8080

# The server reads ANTHROPIC_API_KEY from the environment.
# Pass it with: docker run -e ANTHROPIC_API_KEY=sk-ant-... ...
CMD ["/app/chat-backend"]
```

Evidence: `L-capstone-multiplatform-chat/Dockerfile:1-29`.

## Build and run

```bash
# From parent directory containing both packages:
docker build \
    -f L-capstone-multiplatform-chat/Dockerfile \
    -t chat-backend \
    L-capstone-multiplatform-chat/

docker run --rm \
    -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    -p 8080:8080 \
    chat-backend

curl http://localhost:8080/health
# {"status":"ok"}
```

## Server entry point must handle missing key

```swift
// Sources/chat-backend/main.swift
guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
    FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
    exit(1)
}
let client = AnthropicClient(apiKey: apiKey)
let router = buildRouter(service: client)
let app = Application(
    router: router,
    configuration: .init(address: .hostname("0.0.0.0", port: 8080))
)
try await app.runService()
```

## Image size

- Base (`swift:6.1-jammy-slim`): ~180 MB
- Binary (`--static-swift-stdlib`): ~80–120 MB
- Total: 300–400 MB

## Caveat: sibling path dependencies

If your `Package.swift` has `.package(path: "../L2-anthropic-client")`, that sibling is outside the default Docker build context. Either:
- Invoke `docker build` from a parent directory that contains both packages.
- Switch to a versioned git URL for production.

Evidence: `patterns/relative-path-sibling-spm-deps.md`; `decision-records/adr-006-shared-library-promotion-deferred.md`.
