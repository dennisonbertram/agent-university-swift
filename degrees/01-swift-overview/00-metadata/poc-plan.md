# POC Plan — Swift Overview

Progressive levels. Each adds ONE concept and reuses everything below it.

| Level | POC slug | New concept | Reuses |
|-------|----------|-------------|--------|
| L1 | `L1-hello-spm` | SwiftPM exec target, `swift run`, `swift test`, swift-testing | — |
| L2 | `L2-library-with-protocols` | Library target, protocols, generics, error handling, public API | L1 |
| L3 | `L3-cli-argparse` | `swift-argument-parser`, JSON Codable, file I/O | L1, L2 |
| L4 | `L4-concurrency-actors` | async/await, `TaskGroup`, actors, Sendable, cancellation | L1–L3 |
| L5 | `L5-http-service` | Hummingbird routing/middleware/logging | L1–L4 |
| L-capstone | `L-capstone-agent-tool-service` | All combined — CLI + library + HTTP service exposing a tool surface an LLM agent can call; Dockerfile; integration tests | L1–L5 |

Each level produces:
- A working SwiftPM project.
- A test file using swift-testing.
- A README explaining the new concept and how to run it.
- A git commit (red/green/regression trail for feature work).
