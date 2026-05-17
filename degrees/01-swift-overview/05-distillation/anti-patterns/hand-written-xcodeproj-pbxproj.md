# Anti-pattern: hand-writing `.xcodeproj/project.pbxproj` or committing a generated one

**Category**: anti-pattern

## Broken approach
Adding a `.xcodeproj` directory with a hand-crafted `project.pbxproj` to the repo so that "everything ships ready to run."

## Why it fails
- `project.pbxproj` is a giant nested plist with auto-incrementing UUIDs that Xcode loves to rewrite on every Save. Hand-editing produces invalid projects that Xcode silently refuses to open or, worse, opens but builds incorrectly.
- The generated file format is unstable across Xcode versions. A `.pbxproj` written on Xcode 15.4 may not open cleanly in 16.3.
- Multiple developers cause merge conflicts on the file constantly. There's no tool support for resolving them.
- The Swift toolchain doesn't need it — for the iOS app, the source files are the truth and the Xcode project is a wrapper that should be regenerated as needed.

## Right approach
Ship the iOS source files as plain `.swift` in an `iosApp/` directory plus an `OPEN-IN-XCODE.md` that walks through creating a fresh Xcode iOS App project, adding the SwiftPM package as a local dependency, and dropping the `.swift` files in.

```
L-capstone-multiplatform-chat/
├── Package.swift                  # multiplatform SwiftPM package
├── Sources/
│   ├── ChatCore/                  # cross-platform library, includes SwiftUI views
│   ├── chat-backend/              # Hummingbird backend
│   └── ChatMacApp/                # @main macOS App entry
├── iosApp/
│   ├── ChatIOSApp.swift           # @main iOS App entry
│   ├── RootView.swift             # NavigationStack root
│   └── OPEN-IN-XCODE.md           # 10-step walkthrough
```

`OPEN-IN-XCODE.md` shape (excerpt):

> 1. Create a new Xcode iOS App project (SwiftUI, Swift).
> 2. Add this package as a local dependency: File → Add Package Dependencies → Add Local → select the `L-capstone-multiplatform-chat` directory.
> 3. Copy or reference `ChatIOSApp.swift` and `RootView.swift` into the Xcode project.
> 4. Delete the auto-generated `ContentView.swift` and `<AppName>App.swift` from Xcode (to avoid duplicate `@main`).
> 5. Set `ANTHROPIC_API_KEY` in the scheme's environment variables.

The iOS team owns the .xcodeproj; the SwiftPM package owns the logic.

## Variants and trade-offs
- If you genuinely have a multi-developer iOS team building daily, sure, commit the .xcodeproj — but understand the merge cost and the version-pinning constraints.
- For POCs, tutorials, and example repos: don't ship one. The source files + walkthrough is enough.

## Evidence
- POC: `L6-swiftui-ios-app/iosApp/ChatIOSApp.swift` — bare `@main` source file outside any Xcode project.
- POC: `L6-swiftui-ios-app/iosApp/RootView.swift` — bare iOS root view.
- POC: `L6-swiftui-ios-app/OPEN-IN-XCODE.md:1-22` — 9-step walkthrough.
- POC: `L-capstone-multiplatform-chat/iosApp/OPEN-IN-XCODE.md:1-13` — 5-step walkthrough plus env-var setup.
- POC: There is no `.xcodeproj/` under any POC root in the corpus.
- See also: ADR `decision-records/adr-009-iosapp-source-files-not-xcodeproj.md`.
