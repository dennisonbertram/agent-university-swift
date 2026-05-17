# Degree 01 — Swift Overview

**Status:** Phase 0 complete (scaffolded). Phase 1+ pending.
**Slug:** `01-swift-overview`
**Audience:** LLM agents (autonomous coding agents)
**Prerequisites:** none (this is the first Swift degree in the ecosystem)
**Estimated POCs:** 7 (L1–L6 + capstone)

## Goal

Teach an LLM agent how to build a full-stack Swift product:
- A typed LLM (Anthropic) client library in Swift.
- A CLI chat tool using it.
- A Hummingbird HTTP service exposing it as a tool surface.
- A SwiftUI macOS chat app using it.
- A SwiftUI iOS chat app sharing code with the macOS app.
- A capstone that unifies all of the above end-to-end.

## Deliverables

- Seven built, tested, committed POCs (`03-pocs/L1-*` through `L-capstone-*`).
- Research corpus (`01-research/`) covering language, SwiftPM (incl. multiplatform), swift-testing, swift-argument-parser, Swift concurrency + streaming, Anthropic Messages API, Hummingbird, SwiftUI (macOS + iOS).
- Planning artifacts (`02-planning/`).
- Distilled knowledge (`05-distillation/`) — gotchas, patterns, anti-patterns, playbooks, before-you-build, decision-records — every claim with evidence.
- Skill pack (`06-skill-pack/`) — navigable, self-contained.
- Readiness assessment (`07-evaluation/readiness.md`) including Xcode-build gates for L5/L6/capstone.
