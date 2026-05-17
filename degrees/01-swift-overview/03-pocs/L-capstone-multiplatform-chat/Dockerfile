# Dockerfile — multi-stage production image for chat-backend
#
# NOTE on build context: this Dockerfile assumes the sibling package
# ../L2-anthropic-client is NOT available inside the Docker build context
# (Docker build context is typically the directory containing the Dockerfile).
# In a real production deployment you would need to either:
#   a) Copy L2-anthropic-client into the build context alongside this package, or
#   b) Publish L2-anthropic-client to a registry and use a versioned dependency.
# The Dockerfile is included here to document the *shape* of a production container
# build — the teaching goal of the capstone — rather than as a directly runnable artifact.

# Stage 1: build
FROM swift:6.1-jammy AS builder
WORKDIR /build

# Copy the package and its sibling dep (see note above about build context)
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
