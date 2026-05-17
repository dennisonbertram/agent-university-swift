# Assumptions

These hold unless evidence falsifies them. The researcher (Phase 2) should test each one.

1. **Swift 6.1.2 is current enough** for an LLM-agent-targeted degree. (If 6.2/6.3 has dropped with a major concurrency or macro change, researcher should flag it.)
2. **swift-testing is the right test framework**, not XCTest. (Swift 6 ships swift-testing as the recommended path forward.)
3. **Hummingbird 2.x is appropriate** for an agent-tool HTTP service. Researcher should confirm 2.x is the current major and that it works on Swift 6.1.x.
4. **`swift-argument-parser` is the canonical CLI lib** for Swift CLI tools.
5. **Sendable + actor isolation** are the load-bearing concurrency primitives for a Swift 6 agent service.
6. **POCs can be built and tested without an external service dependency** (no Redis/Postgres). Capstone may use SQLite via Swift bindings if a stateful tool is needed; researcher to recommend.
