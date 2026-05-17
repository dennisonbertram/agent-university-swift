# Lesson 11 — Dockerizing a Swift Server

[Back to index](../index.md) | Prev: [Lesson 10](lesson-10-end-to-end-integration-testing.md) | Next: [Lesson 12](lesson-12-test-driven-development-in-swift.md)

## Goal

After this lesson you can write a multi-stage Dockerfile for a Hummingbird backend, understand the sibling-dependency caveat, and produce a working container image.

## Prerequisites

[Lesson 7](lesson-07-hummingbird-http-services.md) — Hummingbird server that builds with `swift build`.

## Concepts

### 11.1 Base images

The corpus uses:
- **Build stage**: `swift:6.1-jammy` — full Swift toolchain on Ubuntu 22.04.
- **Runtime stage**: `swift:6.1-jammy-slim` — slimmed Ubuntu 22.04 without the compiler.

`--static-swift-stdlib` links the Swift runtime into the binary so the runtime image does not need to carry the Swift libraries separately.

### 11.2 Multi-stage Dockerfile

```dockerfile
# Dockerfile — multi-stage production image for chat-backend
#
# NOTE on build context: this Dockerfile assumes the sibling package
# ../L2-anthropic-client is NOT available inside the Docker build context.
# In a real production deployment you would need to either:
#   a) Copy L2-anthropic-client into the build context alongside this package, or
#   b) Publish L2-anthropic-client to a registry and use a versioned dependency.

# Stage 1: build
FROM swift:6.1-jammy AS builder
WORKDIR /build

COPY . ./L-capstone-multiplatform-chat/
COPY ../L2-anthropic-client ./L2-anthropic-client/

WORKDIR /build/L-capstone-multiplatform-chat
RUN swift build -c release --product chat-backend --static-swift-stdlib

# Stage 2: runtime
FROM swift:6.1-jammy-slim
WORKDIR /app
COPY --from=builder \
     /build/L-capstone-multiplatform-chat/.build/release/chat-backend \
     /app/chat-backend
EXPOSE 8080
ENV PORT=8080
CMD ["/app/chat-backend"]
```

Evidence: `L-capstone-multiplatform-chat/Dockerfile:1-29`.

### 11.3 Sibling dependency caveat

The capstone uses `.package(path: "../L2-anthropic-client")`. Docker's default build context is the directory passed to `docker build`. The sibling package at `../L2-anthropic-client` is **outside** the default context.

Two options:
- **(a)** Invoke `docker build` from the parent directory, assembling both packages into the context.
- **(b)** Publish `L2-anthropic-client` to a git URL or registry and switch from `.package(path:)` to `.package(url:)`.

The Dockerfile documents this caveat explicitly at the top (see the comment block above). For production, option (b) is cleaner.

Evidence: `playbooks/playbook-dockerize-swift-server.md`; `patterns/relative-path-sibling-spm-deps.md`.

### 11.4 Build command

```bash
# From the parent directory that contains both packages:
docker build \
    -f L-capstone-multiplatform-chat/Dockerfile \
    -t chat-backend \
    L-capstone-multiplatform-chat/
```

If the build context doesn't include the sibling, `swift build` inside the container will fail with a missing package error.

### 11.5 Run and smoke test

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    -p 8080:8080 \
    chat-backend

curl http://localhost:8080/health
# {"status":"ok"}
```

### 11.6 Expected image size

With `swift:6.1-jammy-slim` as the runtime base:
- Base layer: ~180 MB
- Binary (with `--static-swift-stdlib`): ~80–120 MB
- Total: roughly 300–400 MB

For smaller images, use a minimal distro as the runtime layer (e.g. Ubuntu minimal) and keep `--static-swift-stdlib`. The corpus does not do this — it stays on `swift:6.1-jammy-slim` for simplicity.

### 11.7 Entry point reads `ANTHROPIC_API_KEY`

The backend exits with a useful error message if the key is absent:

```swift
// Sources/chat-backend/main.swift
guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
    FileHandle.standardError.write(Data("error: ANTHROPIC_API_KEY not set\n".utf8))
    exit(1)
}
```

Always pass the key via `-e ANTHROPIC_API_KEY=...` to `docker run`.

Evidence: `L-capstone-multiplatform-chat/Sources/chat-backend/main.swift:1-15`.

## Pitfalls

- **Sibling `.package(path:)` not in build context** → `swift build` inside Docker fails with package resolution error.
- **Forgetting `--static-swift-stdlib`** → the binary depends on Swift runtime libraries that may not exist in the slim runtime image.
- **Not exposing port 8080** → the container starts but `curl localhost:8080` gets `Connection refused`.

## Recipe

For the complete copy-paste Dockerfile: [recipe-dockerfile-swift-server.md](../recipes/recipe-dockerfile-swift-server.md).

## Recap

- Multi-stage: `swift:6.1-jammy` for build, `swift:6.1-jammy-slim` for runtime.
- `swift build -c release --product <name> --static-swift-stdlib`.
- Sibling `.package(path:)` deps must be in the Docker build context — or switch to versioned git deps.
- Pass `ANTHROPIC_API_KEY` via environment variable at runtime.
- Expected image: 300–400 MB.
