# L1 — hello-spm

Minimal SwiftPM package: executable + library + swift-testing tests.

## What this teaches
- SwiftPM package layout
- Executable vs library targets
- swift-testing baseline (@Test, #expect)
- `swift build`, `swift run`, `swift test`

## Run it
```bash
swift run hello-spm Alice
# → Hello, Alice!

swift run hello-spm
# → Hello, stranger!

swift test
# → 3 tests pass
```

## File layout
- `Package.swift` — manifest
- `Sources/Greeter/Greeter.swift` — pure greeting function (the library)
- `Sources/hello-spm/main.swift` — CLI shim that calls the library
- `Tests/GreeterTests/GreeterTests.swift` — three @Test cases
