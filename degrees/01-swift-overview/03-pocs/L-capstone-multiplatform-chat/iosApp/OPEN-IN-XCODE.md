# iOS App — Open in Xcode

The `iosApp/` directory contains Swift source files for a bare iOS app. To run on a device or simulator:

1. Create a new Xcode iOS App project (SwiftUI, Swift).
2. Add this package as a local dependency: **File → Add Package Dependencies → Add Local** → select the `L-capstone-multiplatform-chat` directory.
3. Copy or reference `ChatIOSApp.swift` and `RootView.swift` into the Xcode project.
4. Delete the auto-generated `ContentView.swift` and `<AppName>App.swift` from Xcode (to avoid duplicate `@main`).
5. Set `ANTHROPIC_API_KEY` in the scheme's environment variables for direct Anthropic access,
   or set `CHAT_BACKEND_URL=http://your-backend:8080` to route through the backend.

These files are not part of the SwiftPM package itself — they exist solely to be dropped into Xcode.
