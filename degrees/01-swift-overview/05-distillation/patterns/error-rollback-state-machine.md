# Pattern: error rollback semantics in chat state machines

**Category**: pattern

## What
A chat turn passes through three observable states: `user-appended → assistant-streaming → assistant-finalised`. If the stream errors before any assistant delta arrives, roll the user message back so the user can retry. If the stream errors after assistant text has already been delivered, keep both the user message AND the partial assistant message — the user has already seen output, throwing it away would be surprising. On user cancellation, keep partial state for the same reason.

## When to apply
- Any UI or CLI that delivers streamed model output and needs to handle failures without dropping conversation context.
- Backend session logic that retains conversation history across turns.

## Canonical code

In a `ChatSession` (CLI/library context):

```swift
public func send(userText: String) -> AsyncThrowingStream<String, Error> {
    let history = self.history
    let service = self.service

    return AsyncThrowingStream { continuation in
        let task = Task {
            await history.append(role: .user, text: userText)
            let snapshot = await history.snapshot()
            let req = MessageRequest(/* ... */, messages: snapshot, stream: true)

            var assistantStarted = false
            do {
                for try await event in service.stream(req) {
                    try Task.checkCancellation()
                    switch event {
                    case .contentBlockDelta(_, let text):
                        if !assistantStarted {
                            await history.append(role: .assistant, text: "")
                            assistantStarted = true
                        }
                        await history.appendOrExtend(role: .assistant, deltaText: text)
                        continuation.yield(text)
                    case .messageStop:
                        continuation.finish()
                        return
                    default: break
                    }
                }
                continuation.finish()
            } catch is CancellationError {
                // Partial response retained; user turn stays in history
                continuation.finish()
            } catch {
                // Hard error: roll back ONLY if assistant never started
                if !assistantStarted { await history.removeLast() }
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

In a `@MainActor` view model:

```swift
private func rollbackAssistant(id: UUID, error: Error) {
    messages.removeAll { $0.id == id }          // assistant placeholder gone
    isStreaming = false
    errorMessage = humanReadable(error)
}
```

The view model uses a UUID-keyed approach so it can find and remove the in-progress assistant message even after deltas have been appended.

## Variants and trade-offs
- The boundary case is "stream errored after at least one delta". The corpus is consistent: keep the partial assistant message and surface the error. Both L3's `ChatSession` and L5's `ChatViewModel` test this explicitly.
- Cancellation is NOT an error — `CancellationError` is caught separately and treated as "user said stop; keep what we have." L3 pins this in BT-006; L5 pins it in BT-005.
- For UI, distinguish "rollback" (remove assistant placeholder, show error) from "finalise" (mark `isStreaming = false`, leave message). The two helpers are separate methods (`rollbackAssistant`, `finishStreaming`).

## Evidence
- POC: `L3-cli-chat/Sources/ChatCore/ChatSession.swift:34-80` — three-branch do/catch with the `assistantStarted` flag.
- POC: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:38-96` — BT-004 (error before delta → rollback) and BT-005 (error after delta → keep partial). Test names: `errorBeforeDeltaRollsBackUser`, `errorAfterOneDeltaKeepsPartial`.
- POC: `L3-cli-chat/Tests/ChatCoreTests/ChatSessionTests.swift:144-181` — BT-006 cancellation keeps partial.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift:61-119` — view-model variant; `rollbackAssistant(id:error:)`.
- POC: `L5-swiftui-macos-app/Tests/ChatAppCoreTests/ChatViewModelTests.swift:73-114` — BT-004 + BT-005 mirror the same semantics.
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/ChatViewModel.swift:60-120` — identical pattern.
- See also: pattern `patterns/asyncthrowingstream-with-onTermination.md`.
