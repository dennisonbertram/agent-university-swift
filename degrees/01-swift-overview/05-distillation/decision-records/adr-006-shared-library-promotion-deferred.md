# ADR-006: Defer the shared `ChatCore` package until the capstone — rule of three

**Date**: 2026-05-16

## Decision
The `AnthropicClient` library lives in L2 and stays the source of truth across L3–L6. The `ChatViewModel` is duplicated in L5 and L6 with deliberate intent. A unified `ChatCore` shared package is only created at the capstone level, where it can absorb the now-stable pieces and become canonical.

## Alternatives considered
- **Create `ChatCore` shared package immediately at L5** — earlier reuse for L6.
- **Promote at L6** — at the point where the second consumer appears.
- **Never unify** — accept the duplication forever; each app owns its own view model.

## Why defer to the capstone
1. **Rule of three.** Abstractions are stabler once you have three independent consumers. L2 was the first user (CLI streaming), L5 the second (macOS view model), L6 the third (multiplatform view model). At L5 we did not yet know whether iOS would need the same view model or a different one — promoting earlier would risk designing the wrong abstraction.
2. **Minimal abstraction tax.** Each POC has ONE Package.swift and clear ownership. Promoting to `ChatCore` at L5 would have meant L5 has both its own Package.swift AND a new shared Package.swift; the capstone is the natural place for the unification because the capstone *is* the place that ships everything together.
3. **Documented duplication.** The L5 / L6 view models are explicitly described as "intentional duplication; promote at capstone." That's a different story than accidental copy-paste.

## Trade-offs accepted
- **Code duplication during the L5 → L6 → capstone span.** Acceptable; the duplicated view model is ~130 lines and changes between iterations were intentional.
- **The capstone has to absorb the duplication.** It does — the capstone's `ChatCore` is the unified version; L5 and L6 remain as historical artifacts (per `02-planning/00-poc-architecture.md` line 354: "L1–L6 remain as historical learning artifacts").

## Evidence
- Planning: `02-planning/01-shared-package-strategy.md` §7 lines 234-249 — "Promotion plan: when does the shared package come into existence?" Explicit table maps stage → action: "L5: duplicated into L5. ... L6: Promotion event. ... capstone: canonical assembly."
- Planning: `02-planning/00-poc-architecture.md` line 244 (L5 "Dependencies on prior POCs" section) — "If promoted, L5 just imports AnthropicClient" but the planning doc accepts ~30-line duplication.
- POC: `L5-swiftui-macos-app/Sources/ChatAppCore/ChatViewModel.swift` and `L6-swiftui-ios-app/Sources/ChatCoreShared/ChatViewModel.swift` — near-identical files; the duplication is real and deliberate.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/` — the unified target; absorbs L2 (via path dep), L3's streaming logic, L5/L6's view model, L4's backend logic.
- See also: pattern `patterns/relative-path-sibling-spm-deps.md`.
