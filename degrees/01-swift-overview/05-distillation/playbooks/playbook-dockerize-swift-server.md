# Playbook: dockerize a Hummingbird Swift server (multi-stage)

**Goal**: A multi-stage Dockerfile that produces a small runtime image for a Hummingbird backend. Document the sibling-dep caveat so future agents are not surprised.

## Prerequisites
- A Hummingbird backend executable (`swift run chat-backend` works locally).
- Docker installed.

## Steps

1. Decide on the base image. The corpus uses `swift:6.1-jammy` for build and `swift:6.1-jammy-slim` for runtime.

2. Decide how to resolve sibling SwiftPM dependencies. The capstone's `Package.swift` uses `.package(path: "../L2-anthropic-client")`. Docker's build context typically excludes the parent directory, so this dependency is invisible to the build by default. Two options:
   - **(a)** Copy `L2-anthropic-client` into the build context alongside the package. Requires `docker build` to be invoked from a parent directory that contains both packages.
   - **(b)** Publish `L2-anthropic-client` to a registry / git URL and switch `.package(path:)` to `.package(url:)`. Cleaner for production; out of scope for the capstone POC.

3. Write the Dockerfile and document the caveat at the top:
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
   COPY --from=builder /build/L-capstone-multiplatform-chat/.build/release/chat-backend /app/chat-backend
   EXPOSE 8080
   ENV PORT=8080
   CMD ["/app/chat-backend"]
   ```

4. Build (acknowledging the build-context caveat above):
   ```bash
   # From a directory above the two sibling packages:
   cd parent-of-both-packages/
   docker build -f L-capstone-multiplatform-chat/Dockerfile -t chat-backend L-capstone-multiplatform-chat/
   # In the real case you'd assemble the build context first.
   ```

5. Run:
   ```bash
   docker run --rm -e ANTHROPIC_API_KEY=$KEY -p 8080:8080 chat-backend
   curl http://localhost:8080/health
   ```

## You'll know it worked when…
- `docker build` exits 0 (with the build context including L2).
- `docker run` starts and `/health` returns `{"status":"ok"}`.
- The image size is roughly 300-400 MB (Swift slim base + ~80MB binary).

## Variants and trade-offs
- For production, switch `.package(path:)` to a real registry URL and drop the second `COPY`.
- The `--static-swift-stdlib` flag links Swift runtime into the binary; the runtime image base could then be a much smaller distro. The corpus stays on the standard `swift:6.1-jammy-slim` for simplicity.
- The Dockerfile is documented as a "shape" rather than a directly runnable artifact — the comment at the top makes that explicit.

## Evidence
- POC: `L-capstone-multiplatform-chat/Dockerfile:1-29` — full Dockerfile with caveat comment.
- POC: `L-capstone-multiplatform-chat/README.md:43-49` — README's "Dockerize the backend" section.
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/main.swift:1-15` — entry point that reads `ANTHROPIC_API_KEY` and binds to port 8080.
- See also: pattern `patterns/relative-path-sibling-spm-deps.md`, ADR `decision-records/adr-006-shared-library-promotion-deferred.md`.
