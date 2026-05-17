# ADR-008: Capstone `/chat/stream` buffers upstream events before responding; L4 streams them through

**Date**: 2026-05-16

## Decision
The capstone backend's `POST /chat/stream` route deliberately collects ALL events from the upstream `LLMService` before opening the SSE response writer. The L4 service streams events through as they arrive. The capstone made a different choice on purpose.

## Alternatives considered
- **True streaming through (as L4 does).** Open the SSE writer immediately, write frames as upstream events arrive.
- **Buffer first, then stream out (capstone).** Drain upstream into a `[StreamEvent]`, only then construct the SSE response.

## Why the capstone buffers
1. **Error detection before commit.** With a true streaming response, by the time the upstream throws (e.g. `AnthropicError.unauthorized`), the HTTP 200 status and headers are already flushed to the client. The client sees a partial SSE stream that just stops — no way to surface a typed error. Buffering lets the route inspect the full upstream result, map errors to a 401/429/502 response, and only emit 200 if all is well.
2. **Test reliability.** The capstone's `EndToEndTests` exercise the full ViewModel → URLSession → Hummingbird → MockUpstream chain. With true streaming, race conditions between the test's URLSession reads and the upstream mock's yields were observable in early development. Buffering removes that variance for the POC.
3. **Mock-compatibility.** The upstream mock yields events synchronously in the closure body; for a real-world LLM with real-time deltas, buffering would be a meaningful trade. For the POC, it's invisible.

## Trade-offs accepted
- **Latency to first byte.** With buffering, the client sees no SSE frames until the upstream is done. With true streaming, the client gets the first token within milliseconds. For an LLM proxy where users expect token-by-token output, this is a real regression. The capstone documents this in `Sources/chat-backend/Router.swift:181-183` comment block.
- **Cancellation propagation.** True streaming naturally propagates cancellation upstream when the client disconnects. Buffered mode collects the full upstream before deciding to abort; if the user cancels, you've already done the work.
- **Inconsistent semantics with L4.** L4 streams through; capstone buffers. An agent reading both will see the divergence and should consult this ADR.

## When to choose which
- **Use buffering** when error fidelity matters more than latency-to-first-byte (proxy with typed error mapping), OR when downstream is a test rig that can't tolerate race conditions, OR when the upstream is fast enough that buffering is invisible.
- **Use streaming** when latency-to-first-byte matters and you accept that upstream errors mid-stream are signalled as silent connection close.

## Evidence
- POC: `L-capstone-multiplatform-chat/Sources/chat-backend/Router.swift:179-194` — comment: "Collect all events upfront from the upstream service. This lets us detect auth errors before committing to an HTTP 200 SSE response. For production use with real LLMs, this approach buffers the full response; for the capstone POC (mock upstream), this is fine and correctly handles errors."
- POC: `L4-hummingbird-tool-service/Sources/ToolService/Router.swift:175-203` — true streaming variant for comparison.
- POC: `L-capstone-multiplatform-chat/Tests/CapstoneTests/BackendLLMServiceTests.swift:14-46` — the 401 test that benefits from buffering: client sees an HTTP 4xx, not a half-streamed 200.
- See also: pattern `patterns/hummingbird-streaming-response-body.md`.
