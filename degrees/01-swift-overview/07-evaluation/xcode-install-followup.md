# Post-Xcode-install follow-up

After Xcode finishes downloading and installing from the App Store, run these commands once to switch the active toolchain from Command Line Tools to full Xcode:

```bash
# 1. Launch Xcode once so it can install additional required components.
open -a Xcode
# (Accept the license, let it install platforms when prompted.)

# 2. Switch the active developer directory from CLT to Xcode.
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# 3. Accept the license non-interactively for the rest of the toolchain.
sudo xcodebuild -license accept

# 4. Verify.
xcode-select -p           # should now be /Applications/Xcode.app/Contents/Developer
xcodebuild -version       # should print Xcode 16.x (or whatever shipped)
xcrun --show-sdk-path     # should now resolve to iPhoneSimulator/iPhoneOS SDKs
xcrun simctl list devices | head -10   # should list simulators
```

## After that, exercise the iOS POCs

### L6 — open the multiplatform package in Xcode
```bash
open -a Xcode /Users/dennison/develop/agent-university/swift/degrees/01-swift-overview/03-pocs/L6-swiftui-ios-app/Package.swift
```
Then follow `OPEN-IN-XCODE.md` in that POC: create a new iOS App project, add the local Swift package, copy `iosApp/ChatIOSApp.swift` and `iosApp/RootView.swift` into the project, set the `ANTHROPIC_API_KEY` env var in the Xcode scheme, run on iPhone Simulator.

### L-capstone — same flow with the capstone iosApp
```bash
open -a Xcode /Users/dennison/develop/agent-university/swift/degrees/01-swift-overview/03-pocs/L-capstone-multiplatform-chat/Package.swift
```
Follow `iosApp/OPEN-IN-XCODE.md`.

### L5 — visually verify the macOS app
```bash
cd /Users/dennison/develop/agent-university/swift/degrees/01-swift-overview/03-pocs/L5-swiftui-macos-app
ANTHROPIC_API_KEY=… swift run ChatMacApp
# A real macOS window should open. Type a message, see streaming response.
```

### Smoke-test the capstone end-to-end
```bash
# Terminal 1 — backend
cd /Users/dennison/develop/agent-university/swift/degrees/01-swift-overview/03-pocs/L-capstone-multiplatform-chat
ANTHROPIC_API_KEY=… swift run chat-backend

# Terminal 2 — macOS app pointing at the backend
cd /Users/dennison/develop/agent-university/swift/degrees/01-swift-overview/03-pocs/L-capstone-multiplatform-chat
CHAT_BACKEND_URL=http://localhost:8080 swift run ChatMacApp
```

## Disk space note

Full Xcode is ~12-15 GB compressed download, ~50 GB on disk after install. iOS Simulator runtimes add another ~7 GB per platform. Make sure you have at least 70 GB free before clicking Get.

## Estimated time

- Download: 30-90 minutes depending on connection
- Install + first-launch component install: 10-20 minutes
- Total: budget 1-2 hours
