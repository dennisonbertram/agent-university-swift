# ADR-010: `HTTPTransport.bytes(_:)` returns `AsyncThrowingStream<UInt8, Error>`, NOT `URLSession.AsyncBytes`

**Date**: 2026-05-16

## Decision
The L2 `HTTPTransport` protocol's streaming method returns `(AsyncThrowingStream<UInt8, Error>, HTTPURLResponse)`. The production `URLSessionTransport` adapts `URLSession.AsyncBytes` into this stream at the boundary. Mocks construct streams directly from canned `Data`.

## Alternatives considered
1. **Return `URLSession.AsyncBytes` directly** — most fidelity to Foundation; tests cannot mock it because the type has no public init (see gotcha `gotchas/urlsession-asyncbytes-has-no-public-init.md`).
2. **Return `AsyncStream<Data>` of chunks** — works for mocks but loses the byte-level granularity SSE parsing wants.
3. **Return `AsyncThrowingStream<UInt8, Error>` (chosen)**.

## Why `AsyncThrowingStream<UInt8, Error>`
1. **Testability**. Tests can build a stream from `Array(string.utf8)` and inject it through the protocol seam. No live network in unit tests. The corpus's SSE parser tests (L2) all feed canned byte streams this way.
2. **Cancellation propagates**. `AsyncThrowingStream` continuations support `onTermination`, which lets the consumer's `break` reach back to cancel the URLSession task (see pattern `patterns/asyncthrowingstream-with-onTermination.md`).
3. **Byte-level granularity for SSE**. The L2 parser reads byte-by-byte and handles CRLF / LF / blank-line dispatch itself. Coarser chunking would force re-splitting at the parser layer.
4. **Sendable across boundaries**. `AsyncThrowingStream` is `Sendable`; both production and test streams flow through actor boundaries cleanly.

## Trade-offs accepted
- **One extra adapter layer**. The production `URLSessionTransport.bytes(_:)` spins up a `Task` that iterates `URLSession.AsyncBytes` and yields each byte into the new stream. ~15 lines of adapter code. Acceptable.
- **No request/response association at the stream level**. The protocol returns the stream and the `HTTPURLResponse` separately; callers handle correlation. Acceptable; the only consumer (L2's `AnthropicClient.stream`) does exactly this.
- **Slight perf cost**. The byte-by-byte yield in the adapter is not zero-cost. For SSE parsing of typical token-rate streams (hundreds of bytes / second), this is invisible.

## Evidence
- POC: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:1-12` — leading comment block documents the exact rationale: "URLSession.AsyncBytes has no public initializer, making it untestable. URLSessionTransport adapts URLSession.AsyncBytes into AsyncThrowingStream<UInt8, Error>."
- POC: `L2-anthropic-client/Sources/AnthropicClient/HTTPTransport.swift:34-46` — full adapter.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/MockHTTPTransport.swift:22-43` — mock constructs the stream from `Data`.
- POC: `L2-anthropic-client/Tests/AnthropicClientTests/SSEParserTests.swift:8-15` — `makeByteStream(from:)` helper used by every parser test.
- See also: gotcha `gotchas/urlsession-asyncbytes-has-no-public-init.md`, pattern `patterns/http-transport-seam.md`, anti-pattern `anti-patterns/urlsession-asyncbytes-in-public-protocol.md`.
