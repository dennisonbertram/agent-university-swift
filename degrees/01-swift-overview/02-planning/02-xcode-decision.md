# Xcode Decision — Do We Need It, and When?

> Grounded in `01-research/05-swiftui-multiplatform.md` §8 and the runtime probe at `/tmp/swift-research-probe/swiftui-test/`.

## 1. What the probe actually proved

The runtime probe at `/tmp/swift-research-probe/swiftui-test/` ran on Swift 6.1.2 with CLT-only on macOS 15. The probe:

- Wrote a Swift file containing `import SwiftUI`, `@main struct App: App`, `WindowGroup`, and `Text("Hello")`.
- Ran `swift build` — exit 0, `Build complete! (34.67s)`.

The probe **compiled** SwiftUI code. It did **not**:
- Produce a launchable `.app` bundle with an `Info.plist`, app icon, or `LSApplicationCategoryType`.
- Code-sign anything.
- Launch a window.
- Verify that the resulting binary, when run, actually opens a window or just exits silently.

So the load-bearing finding from the probe is: **SwiftUI compiles with CLT — type-checking the API surface works**. That is a meaningful unblock for `swift build` CI on SwiftUI macOS code, and it means the L5 codebase can be written and statically verified without Xcode. It does **not** prove that L5 can be *demoed* end-to-end without Xcode.

## 2. What requires Xcode regardless

| Capability | CLT only | Xcode required |
|------------|----------|-----------------|
| `swift build` macOS SwiftUI app target | ✅ | — |
| `swift test` for view-model unit tests | ✅ | — |
| Running an iOS app in the simulator | ❌ | ✅ |
| Building for iOS device | ❌ | ✅ (and provisioning) |
| Code signing | ❌ | ✅ (or `codesign` CLI with a cert) |
| SwiftUI Previews (`#Preview`) | ❌ | ✅ |
| Instruments profiling | ❌ | ✅ |
| Interface Builder / xib | ❌ | ✅ (not relevant — we use SwiftUI) |

For our scope:
- **L1–L4**: no Xcode dependency. CLT is sufficient.
- **L5 (macOS app)**: build works with CLT (proved). Running and demoing might work with CLT — see §3.
- **L6 (iOS app)**: Xcode is mandatory (iOS simulator, no exception).
- **capstone**: needs Xcode for the iOS shell; the macOS shell and backend do not.

## 3. Can L5 actually run without Xcode?

The probe didn't test this. The question is: when `swift build` produces `.build/debug/ChatMac`, does executing that binary launch a SwiftUI window?

What's known (from Apple's docs and the SwiftUI App lifecycle):
- The `App` protocol works without Info.plist for `swift run` style execution; `WindowGroup` opens a window when the run loop starts.
- However, macOS apps that are not in a proper `.app` bundle may be misclassified as "agent" or "background" processes by LaunchServices, which can prevent window display or activation.
- Some SwiftUI macOS apps that "just work" with `swift run` will appear without a Dock icon and require manual activation.

What's unknown until we test:
- Whether the binary launches a usable window from `swift run` in this exact Swift 6.1.2 / macOS 15 setup.
- Whether the window is interactive (keyboard input, focus) without the surrounding `.app` bundle's `NSApplication` configuration.

## 4. Decision

**For L5, attempt CLT-only first. Verify with the dedicated probe below. If it works, no Xcode install is needed for L5. If it does NOT work, then either:**
- **(a)** wrap the produced binary in a minimal `.app` bundle manually (a small `Info.plist` + directory layout — feasible, ~50 lines of scripting), OR
- **(b)** install Xcode at that point and use `xcodebuild` for L5 as well.

**For L6, Xcode install is required.** Defer the install request until L6 begins. This minimizes blocking on a multi-gigabyte download until it is genuinely needed.

**For capstone**, Xcode is required for the iOS shell.

Summary timeline:
| Level | Action |
|-------|--------|
| L1–L4 | CLT only, no Xcode install needed |
| L5 | Attempt CLT-only build and run; document the result. Do not block on Xcode |
| L6 | Pause; ask user to confirm Xcode 16.3+ installed before scaffolding |
| capstone | Xcode required; user should already have it from L6 |

## 5. The verification probe for L5

Before declaring L5 unblocked on CLT, run this probe. Keep it tiny — a 10-line SwiftUI app that demonstrates a real window with interactive input. Suggested layout:

```
/tmp/l5-verify/
├── Package.swift
└── Sources/L5Verify/
    └── L5VerifyApp.swift
```

`Package.swift`:
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L5Verify",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "L5Verify"),
    ]
)
```

`L5VerifyApp.swift`:
```swift
import SwiftUI

@main
struct L5VerifyApp: App {
    @State private var text = ""

    var body: some Scene {
        WindowGroup {
            VStack {
                TextField("Type here", text: $text)
                    .padding()
                Text("You typed: \(text)")
                    .padding()
            }
            .frame(width: 300, height: 200)
        }
    }
}
```

Verification steps:
1. `swift build` — exit code 0 confirms it compiles (already proved generally).
2. `swift run L5Verify` — should launch a window. Verify:
   - A window appears on screen.
   - It accepts keyboard input in the `TextField`.
   - The `Text` view updates as the user types.
3. If a window does NOT appear:
   - Check `ls .build/debug/L5Verify` — confirm the binary exists.
   - Try `open .build/debug/L5Verify` — sometimes activates differently than direct exec.
   - If still no window, fall back to manual `.app` wrapper or Xcode.

The probe is single-purpose. Once verified, L5 proceeds with the same pattern.

## 6. What if the verification fails?

Three escape hatches in order of preference:

**(a) Minimal `.app` bundle wrapper.** A Bash script that creates `L5Verify.app/Contents/{MacOS,Info.plist}`, copies the binary in, and runs `open L5Verify.app`. About 20 lines of script. Documented in this file as Appendix A if needed.

**(b) `xcodebuild` against an Xcode project generated from `Package.swift`.** Even without opening Xcode interactively, `xcodebuild -scheme L5 build` produces a proper `.app`. Requires Xcode install but not Xcode interactive use.

**(c) Install Xcode and use it normally for L5.** This is the fallback that obviously works but burns time.

Recommend (a) first if (a) is needed at all — keep CLT-only as long as possible to maximize the educational value (showing what each tool does and does not give you).

## 7. Recommendation to coordinator

- Proceed through L1–L4 with CLT.
- At L5 entry: run the verification probe described in §5. Capture the outcome in `04-logs/`.
- If L5 verification succeeds: proceed without Xcode.
- If L5 verification fails: implement the `.app` wrapper (§6a) and document.
- Before L6: ask user to install Xcode 16.3+ if not already present. Verify with `xcodebuild -version`.

This sequencing means Xcode is only requested at the moment it becomes necessary, and the educational value of "what works with CLT vs Xcode" is preserved as a learning checkpoint between L5 and L6.
