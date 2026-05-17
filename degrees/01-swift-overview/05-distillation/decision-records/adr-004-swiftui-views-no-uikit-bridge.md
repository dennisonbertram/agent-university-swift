# ADR-004: SwiftUI views stay cross-platform — no `UIViewRepresentable` / `NSViewRepresentable` in `ChatCore`

**Category**: decision-record

**Date**: 2026-05-16

## Decision
The shared SwiftUI views in `ChatCore` (`ChatScreen`, `MessageRow`, `InputBar`) use only the cross-platform SwiftUI surface — `VStack`, `HStack`, `ScrollView`, `TextField`, `Button`, `NavigationStack`, etc. No `UIViewRepresentable` or `NSViewRepresentable` bridges. The handful of iOS-only modifiers (`.navigationBarTitleDisplayMode(.inline)`, `.submitLabel(.send)`) are guarded with `#if os(iOS)` at the modifier level.

## Alternatives considered
1. **Allow `UIViewRepresentable` in shared views** for richer iOS-specific UI components (e.g. wrapping `UITextView` for advanced text editing). Rejected: forces every shared view to have a macOS counterpart, doubling maintenance.
2. **Per-platform view subdirectories** with `ChatScreen_iOS.swift` and `ChatScreen_macOS.swift`. Rejected: cross-platform view code is small, and divergence-by-modifier handles 95% of cases.
3. **Push all platform-specific bridging up to the app shell** (chosen).

## Why no UIKit/AppKit bridge in shared views
1. **`ChatCore` compiles on both platforms unchanged.** Bridges by their nature can only compile on one platform; once you have a bridge, you need `#if` guards around it, and the cross-platform surface fragments quickly.
2. **The view model is also UI-framework-free** (see ADR-005). If a `UIViewRepresentable` shows up in shared views, eventually the view model gets pulled in to feed it.
3. **`#if os(iOS)` at the modifier level is enough.** The corpus's modifier-level guards cover all observed divergences without splitting view files.
4. **iOS-specific UIKit bridging belongs in the app shell.** If you genuinely need a `UITextView`-based input in the iOS app, define it in `iosApp/` and pass the resulting `Binding<String>` up to the shared `ChatScreen`.

## Trade-offs accepted
- **No advanced platform-specific UI**. The shared input bar is a SwiftUI `TextField` with `.lineLimit(1...4)`, not a fully-featured editor. Adding e.g. attributed-text editing would be an iOS-shell-only feature.
- **Some duplication in app shells** if both platforms want a custom component (e.g. a macOS `Settings` scene + an iOS settings sheet). Acceptable because the divergence is structural, not tactical.

## Evidence
- POC: `L6-swiftui-ios-app/Sources/ChatCoreShared/Views/ChatScreen.swift` and `Views/InputBar.swift` — only `#if os(iOS)` guards on individual modifiers; no representable bridges.
- POC: `L-capstone-multiplatform-chat/Sources/ChatCore/Views/` — same shape.
- Planning: `02-planning/01-shared-package-strategy.md` §6 lines 219-233 — explicit table: `UIViewRepresentable` / `NSViewRepresentable` "per-platform — only if bridging needed" and the rule "Guards should appear in the **app shells**, not in `ChatCore`."
- Research: `01-research/05-swiftui-multiplatform.md` §5 lines 263-299 — cross-platform view subset.
- See also: pattern `patterns/cross-platform-swiftui-guards.md`, ADR `decision-records/adr-005-no-import-swiftui-in-viewmodel.md`.
