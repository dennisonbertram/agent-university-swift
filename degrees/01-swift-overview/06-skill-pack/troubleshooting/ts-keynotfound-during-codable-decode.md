# Troubleshooting — `Key not found: "maxTokens"` during Codable decode

[Back to index](../index.md)

## Symptom

```
HTTP 400 from POST /chat: decode failed: Key not found: "maxTokens"
```

or in Swift test output:

```
DecodingError.keyNotFound(CodingKeys(stringValue: "maxTokens", intValue: nil), ...)
```

The wire payload has `"max_tokens"` (correct), but the decoder cannot find it.

## Diagnosis

You are using `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` on a type that already declares explicit `CodingKeys` with snake_case raw values.

The strategy transforms `"max_tokens"` → `"maxTokens"` before matching CodingKeys. Then it looks for a `CodingKey` whose raw value is `"maxTokens"`. But `MessageRequest.CodingKeys.maxTokens` has raw value `"max_tokens"` — not `"maxTokens"`. Result: key not found.

## Fix

Use a plain `JSONDecoder()` (no strategy) for types with explicit snake_case `CodingKeys`:

```swift
// Wrong:
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let payload = try decoder.decode(MessageRequest.self, from: data)

// Correct:
let decoder = JSONDecoder()    // plain, no strategy
let payload = try decoder.decode(MessageRequest.self, from: data)
```

If you have a mix of types — some with explicit `CodingKeys` and some without — keep two separate decoder instances.

## See also

- Distillation: `gotchas/snake-case-codable-double-transform.md`
- Lesson: [lesson-03-typed-clients-with-codable.md](../lessons/lesson-03-typed-clients-with-codable.md)
- Anti-pattern: `anti-patterns/convert-from-snake-case-on-explicit-codingkeys.md`
- ADR: `decision-records/adr-007-snake-case-codable-via-explicit-codingkeys.md`
