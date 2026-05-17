# Troubleshooting — `swift run` Produces No Window on macOS

[Back to index](../index.md)

## Symptom

`swift build` exits 0. The binary exists at `.build/debug/ChatMacApp`. `swift run ChatMacApp` may:
- Print nothing and exit immediately.
- Run silently with nothing in the Dock.
- Show an unfocusable, non-interactive window.

## Diagnosis

`swift run` produces a raw Mach-O binary without an `.app` bundle wrapper. macOS LaunchServices requires a `.app` bundle with an `Info.plist` to surface a GUI window. Without it, macOS may classify the binary as a background agent and refuse to show its windows.

`swift build` exit 0 confirms the code **compiles** correctly. This is valuable and real — you can CI on it. But it does not confirm the app launches interactively.

## Fix

Accept the constraint and work around it:

| Goal | Tool |
|------|------|
| Verify code compiles | `swift build` (works with CLT only) |
| Run view model unit tests | `swift test` (works with CLT only) |
| Launch the macOS app interactively | Open in Xcode and run from there |
| iOS testing | Xcode is mandatory |

If you need a hand-crafted `.app` bundle without Xcode:
1. Create `MyApp.app/Contents/MacOS/` directory.
2. Copy the binary there.
3. Create `MyApp.app/Contents/Info.plist` with the minimum keys (`CFBundleExecutable`, `LSUIElement`).
4. `open MyApp.app`

This approach is fragile and not recommended for ongoing development.

## See also

- Distillation: `gotchas/swiftui-builds-with-clt-but-cannot-launch.md`
- Lesson: [lesson-08-swiftui-macos-app.md](../lessons/lesson-08-swiftui-macos-app.md)
- Planning: `degrees/01-swift-overview/02-planning/02-xcode-decision.md`
