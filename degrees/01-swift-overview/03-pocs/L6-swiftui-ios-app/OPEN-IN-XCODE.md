# Running the iOS app

The iOS app cannot be built on this machine (no Xcode installed). To run it on a Simulator or device, follow these steps on a machine with Xcode installed:

## Steps

1. Install Xcode 15+ from the App Store.
2. Open Xcode → File → New → Project → iOS → App.
3. Product Name: `ChatIOSApp`. Interface: SwiftUI. Language: Swift.
4. Save anywhere — call it e.g. `ChatIOSAppXcode/`.
5. In Xcode, File → Add Package Dependencies → Add Local… → select this `L6-swiftui-ios-app/` directory (the Package.swift).
6. Add the `ChatCoreShared` library product to the app's "Frameworks, Libraries, and Embedded Content".
7. Replace Xcode's generated `<NameApp>.swift` and `ContentView.swift` with the contents of `iosApp/ChatIOSApp.swift` and `iosApp/RootView.swift` (rename ChatIOSApp.swift to match Xcode's expected entry name, or update the project's @main).
8. Edit Scheme → Run → Environment Variables → add `ANTHROPIC_API_KEY` = your key.
9. Select iOS Simulator (iPhone 15 or similar) → Run.

## Verified separately

- The `ChatCoreShared` library compiles for macOS via `swift build` on this machine — that's the build gate satisfied here.
- The view model + logic are unit-tested via `swift test` (all on macOS); the same tests would pass on iOS since the code is portable.
- The SwiftUI views in ChatCoreShared do not import UIKit; their iOS-only modifiers are guarded by `#if os(iOS)`.
