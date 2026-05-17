# Agent Debugging Workflow

[Back to index](../index.md) | Related: [ai-system-prompt-swift.md](ai-system-prompt-swift.md), [troubleshooting/](../troubleshooting/)

When a build fails, a test fails, or a runtime error appears, follow this lookup order. Match the symptom to the correct troubleshooting entry before writing new code.

---

## Step 1 — Identify the symptom category

### Compiler errors

| Symptom | Go to |
|---|---|
| `nonisolated global shared mutable state` | [ts-nonisolated-global-shared-mutable-state](../troubleshooting/ts-nonisolated-global-shared-mutable-state.md) |
| `type ... does not conform to 'Sendable'` | [ts-sendable-type-cannot-be-marshalled](../troubleshooting/ts-sendable-type-cannot-be-marshalled.md) |
| `cannot find 'HBApplication'` or `'HBRequest'` | [ts-hummingbird-1x-types-in-2x-project](../troubleshooting/ts-hummingbird-1x-types-in-2x-project.md) |
| `cannot find 'NSView'` on iOS build | [ts-multiplatform-package-fails-ios-only-api](../troubleshooting/ts-multiplatform-package-fails-ios-only-api.md) |

### Test failures

| Symptom | Go to |
|---|---|
| `swift test` crashes with `isolation()` or Objective-C exception about `platforms:` | [ts-swift-test-fails-without-platforms](../troubleshooting/ts-swift-test-fails-without-platforms.md) |
| `KeyNotFound` during Codable decode | [ts-keynotfound-during-codable-decode](../troubleshooting/ts-keynotfound-during-codable-decode.md) |
| Test mock is not `Sendable` | [ts-sendable-type-cannot-be-marshalled](../troubleshooting/ts-sendable-type-cannot-be-marshalled.md) |

### Network / API errors

| Symptom | Go to |
|---|---|
| HTTP 401 from Anthropic | [ts-anthropic-401-unauthorized](../troubleshooting/ts-anthropic-401-unauthorized.md) |
| HTTP 429 from Anthropic | [ts-anthropic-429-rate-limited](../troubleshooting/ts-anthropic-429-rate-limited.md) |
| SSE stream hangs, no completion | [ts-sse-stream-hangs-no-done-marker](../troubleshooting/ts-sse-stream-hangs-no-done-marker.md) |
| No streaming output at all | [ts-stream-true-flag-missing-from-request](../troubleshooting/ts-stream-true-flag-missing-from-request.md) |

### Hummingbird server errors

| Symptom | Go to |
|---|---|
| Route returns 404 | [ts-hummingbird-route-returns-404](../troubleshooting/ts-hummingbird-route-returns-404.md) |
| Middleware not applied to some routes | [ts-hummingbird-middleware-not-applied](../troubleshooting/ts-hummingbird-middleware-not-applied.md) |
| `URLSession.bytes` won't mock | [ts-urlsession-bytes-cannot-be-mocked](../troubleshooting/ts-urlsession-bytes-cannot-be-mocked.md) |
| 1.x type names in a 2.x project | [ts-hummingbird-1x-types-in-2x-project](../troubleshooting/ts-hummingbird-1x-types-in-2x-project.md) |

### SwiftUI / multiplatform errors

| Symptom | Go to |
|---|---|
| macOS window does not open | [ts-swiftui-macos-window-does-not-open](../troubleshooting/ts-swiftui-macos-window-does-not-open.md) |
| iOS-only API breaks macOS build | [ts-multiplatform-package-fails-ios-only-api](../troubleshooting/ts-multiplatform-package-fails-ios-only-api.md) |
| Async task continues after view disappears | [ts-async-task-leaks-after-view-disappears](../troubleshooting/ts-async-task-leaks-after-view-disappears.md) |

---

## Step 2 — If no entry matches

1. Check the **gotchas** list in the distillation corpus: `05-distillation/gotchas/` — 15 files covering the most common surprises.
2. Check the **playbooks**: `05-distillation/playbooks/` — 10 step-by-step debug workflows.
3. Check the **anti-patterns**: `05-distillation/anti-patterns/` — 7 files on patterns that look right but aren't.

---

## Step 3 — Root-cause before patching

Do NOT add a workaround before understanding the root cause. Apply this process:

1. **Reproduce** the failure with the smallest possible reproduction (one test, one file).
2. **Read the error message fully** — Swift 6 concurrency errors are verbose but precise.
3. **Identify the isolation domain** — which actor/thread is the value on, and which one is trying to access it?
4. **Look up the canonical fix** in the troubleshooting entry or pattern.
5. **Apply the minimal fix** — don't restructure unrelated code.
6. **Verify** `swift build` succeeds, then `swift test` passes.

---

## Step 4 — After fixing, prevent regression

- Add a test that would have caught the bug.
- If the fix is structural (protocol seam, actor boundary), add a comment linking to the relevant distillation pattern.
- If the bug involved a gotcha (e.g., missing `platforms:`, wrong SSE termination), add it to the checklist you run next time.

---

See also: [ai-checklist-before-writing-swift](ai-checklist-before-writing-swift.md), [ai-when-to-use-which-pattern](ai-when-to-use-which-pattern.md)

Evidence: `05-distillation/gotchas/`, `05-distillation/playbooks/`, `05-distillation/anti-patterns/`.
