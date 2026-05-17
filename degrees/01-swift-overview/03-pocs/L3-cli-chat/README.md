# L3 — cli-chat

Terminal chat with Claude. Streaming output, multi-turn history, swift-argument-parser CLI.

## What this teaches
- swift-argument-parser with AsyncParsableCommand
- Wrapping an external client (L2 AnthropicClient) behind a local protocol (LLMService)
- Actor-isolated conversation state
- Bridging AsyncThrowingStream layers — the network stream feeds a higher-level stream
- Error rollback semantics that keep the user in control

## Build and run
```bash
export ANTHROPIC_API_KEY=...
swift run chat
swift run chat --model claude-sonnet-4-5-20250929 --system "be brief"
```

## Run tests (no API key required)
```bash
swift test
```

## Dependencies
- `../L2-anthropic-client` (sibling POC, SwiftPM relative path)
- `swift-argument-parser` 1.5.0+
