# Assumptions

These hold unless evidence falsifies them. The researcher (Phase 2) tests each one.

1. **Swift 6.1.2 is current enough** for this degree. If a newer Swift has dropped with a material change to concurrency, macros, or SwiftUI, researcher should flag it.
2. **swift-testing** (not XCTest) is the canonical test framework for SwiftPM library/executable targets in Swift 6. XCTest may still be required for SwiftUI UI tests in Xcode projects — researcher to confirm.
3. **Anthropic Messages API** is the LLM target. Auth via `ANTHROPIC_API_KEY` env. Streaming via SSE. Model defaults to `claude-3-5-sonnet-latest` (researcher to confirm current best model id).
4. **No existing official Anthropic Swift SDK exists** at sufficient quality, OR if one exists, we build our own as a teaching exercise. Researcher must check this.
5. **Hummingbird 2.x** is appropriate for the L4 service. Researcher confirms current major and Swift 6.1 compatibility.
6. **SwiftPM multiplatform packages** can declare `iOS` + `macOS` platforms in `Package.swift` and be consumed by an Xcode project for the app shells. Researcher confirms the canonical structure.
7. **SwiftUI APIs for macOS and iOS overlap enough** that one set of views can serve both with light `#if os(...)` guards. Researcher confirms the chat-app surface (TextField, List, ScrollView, async tasks) is portable.
8. **Full Xcode is required** to build L5/L6/capstone. We will pause before L5 to confirm install.
9. **No on-device LLM** — the LLM lives at api.anthropic.com. CoreML/MLX is out of scope.
10. **All POCs can be built without external service dependencies other than Anthropic API.** No Redis/Postgres. Capstone backend uses in-memory state.
