# Omnia

> **Your AI. Your Keys. Your Choice.**

A beautiful, privacy-first native AI workspace for OpenAI-compatible APIs.

<p align="center">

![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20iPadOS%20%7C%20macOS-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-success)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

</p>

---

## Overview

Omnia is a native Apple platform application that allows users to connect to any OpenAI-compatible AI provider.

Unlike traditional AI applications, Omnia does not provide AI models.

Instead, Omnia gives users a beautiful, fast and privacy-focused interface to their own infrastructure.

No subscriptions.

No proxy servers.

No vendor lock-in.

Your endpoint.

Your API key.

Your conversations.

---

## Repository Contents

The repository is a Swift 6 workspace with a strict layered architecture
(`Package.swift` plus six local packages under `Packages/`):

| Package | Layer | Responsibility |
|---|---|---|
| `OmniaFoundation` | Foundation | Primitives shared by all layers |
| `OmniaDomain` | Domain | Capabilities, models, and business rules |
| `OmniaInfrastructure` | Infrastructure | Storage, transports, credential handling |
| `OmniaApplication` | Application | Use cases and application services |
| `OmniaPresentation` | Presentation | SwiftUI views and platform-independent state |
| `OmniaApp` | App | Composition root, app shell, and entry points |

The native app targets live in `App/`: the Xcode workspace (`Omnia.xcworkspace`)
with the macOS host (`Omnia`) and the iOS/iPadOS host (`OmniaiOS`).

## Building & Testing

Omnia is written in Swift 6 and targets macOS 13+ and iOS 16+.

- **Tests.** The standard test suite runs with the Swift Package Manager:

  ```bash
  swift test                                     # root package (all six packages)
  cd Packages/OmniaDomain && swift test          # an individual package
  ```

  Tests are deterministic (no network, no sleeps, no global state). The SwiftUI
  view layer is Apple-platform code isolated behind `canImport(SwiftUI)` and is
  not exercised by the Linux test environment; it is verified by review and by
  Apple-platform builds.

- **Apple builds.** Open `Omnia.xcworkspace` in Xcode and run the `Omnia`
  (macOS) or `OmniaiOS` scheme, or build on the command line:

  ```bash
  xcodebuild -workspace Omnia.xcworkspace -scheme Omnia -configuration Release \
    -destination 'platform=macOS' build
  xcodebuild -workspace Omnia.xcworkspace -scheme OmniaiOS -configuration Release \
    -destination 'generic/platform=iOS' build
  ```

- **Linux.** The Linux build and test suite runs in a `swift:6.0` Docker
  container — the standard test environment when no Apple toolchain is
  available on the development host.

> **Note:** the private `.ai/` directory (the project's internal AI
> engineering-process framework) is intentionally not included in the public
> repository. It is not required to build, test, or use Omnia.

---

## Philosophy

Omnia is built around four simple principles.

- 🔒 Privacy First
- 🍎 Native First
- ⚡ Performance First
- ✨ Simplicity First

We believe the AI client should disappear into the background, allowing users to focus entirely on the conversation.

---

## Why Omnia?

Today's AI ecosystem is fragmented.

| Service | Locked Provider |
|----------|-----------------|
| ChatGPT | OpenAI |
| Claude | Anthropic |
| Gemini | Google |

Omnia changes this.

One application.

Unlimited providers.

Your choice.

---

## Features

### Current

- Multiple AI Providers
- OpenAI Compatible API
- Streaming Responses
- Markdown Rendering
- Code Highlighting
- Local Conversation Storage
- Multiple Conversations
- Multiple Connections

### Planned

- Attachments
- Vision Models
- Voice
- Prompt Library
- Workspaces
- Plugins

---

## Supported Providers

Any OpenAI-compatible endpoint including:

- OpenAI
- OmniRoute
- Ollama
- OpenRouter
- LM Studio
- LocalAI
- vLLM
- Groq
- Together AI

---

## Architecture

Omnia follows a strict layered architecture.

```
Presentation
      ↓
Application
      ↓
Domain
      ↓
Infrastructure
      ↓
Foundation
```

More information is available in the Architecture documentation.

---

## Documentation

Project documentation is organized into dedicated sections.

```text
Documentation/

Product/
Architecture/
Design/
Development/
API/
Quality/
RFC/
ADR/
```

---

## Project Status

Current milestone:

> ✅ MVP v0.1 — complete (DES-013 v1.0.0, DES-011 v1.1.0, DES-012 v1.1.0 ratified; issues #120-#125 closed; the runnable macOS app with the Composition Root, app shell, and lifecycle delivered)

Latest release:

> ✅ v0.5.0 (2026-08-07) — the first distributable build: native macOS and iOS apps with streaming conversations, provider connections, and a reproducible release pipeline (see [CHANGELOG.md](CHANGELOG.md)).

Recent work:

> ✅ UX audit (#154) and UI redesign — WCAG AA bubble contrast, Dynamic Type, retry/continue for interrupted responses, and the `OmniaTheme` design-token system.
> ✅ OmniRoute integration — per-provider model/combo recording and routing through the generic OpenAI-compatible provider surface.

Current state:

> The integrated branch is green on the Linux build environment — 1057 tests across all six packages, 0 failures (OmniaFoundation 136, OmniaDomain 319, OmniaApplication 177, OmniaInfrastructure 187, OmniaPresentation 199, OmniaApp 39). The SwiftUI view layer is Apple-platform code isolated behind `canImport(SwiftUI)` and is verified by review and by Apple-platform builds; a physical macOS/iOS launch verification remains a pending platform-specific step (DES-013 §3.6).

---

## Contributing

We welcome contributions.

Please read:

- CONTRIBUTING.md
- Documentation/
- RFC process

before opening a Pull Request.

---

## Roadmap

See:

- [Infrastructure Sprint 1 (DES-010 planning + implementation)](Documentation/Product/Roadmap/INFRASTRUCTURE_SPRINT_1_ROADMAP.md)
- [Domain Sprint 1 (DES-009 implementation)](Documentation/Product/Roadmap/DOMAIN_SPRINT_1_ROADMAP.md)
- [Domain Sprint 2 (DES-009 capability-contract extension)](Documentation/Product/Roadmap/DOMAIN_SPRINT_2_ROADMAP.md)
- [Infrastructure Sprint 2 (DES-010 concrete provider capabilities)](Documentation/Product/Roadmap/INFRASTRUCTURE_SPRINT_2_ROADMAP.md)
- [Application Sprint 1 (DES-011 use cases and application services)](Documentation/Product/Roadmap/APPLICATION_SPRINT_1_ROADMAP.md)
- [Presentation Sprint 1 (DES-012 native user interface)](Documentation/Product/Roadmap/PRESENTATION_SPRINT_1_ROADMAP.md)
- [MVP v0.1 (integration into a runnable application)](Documentation/Product/Roadmap/MVP_V01_ROADMAP.md)
- [Release Engineering Sprint 1 (distribution, signing, and release pipeline)](Documentation/Product/Roadmap/RELEASE_ENGINEERING_SPRINT_1_ROADMAP.md)
- [Infrastructure Sprint 1 Retrospective](Documentation/Development/Retrospectives/INFRASTRUCTURE_SPRINT_1_RETROSPECTIVE.md)

Documentation/Product/Roadmap/

---

## Security

Security issues should **never** be reported publicly.

Please see:

SECURITY.md

---

## License

MIT License

Distributed under the [MIT License](LICENSE).

---

## Our Promise

Omnia will never:

- collect analytics by default
- proxy AI requests
- store API keys remotely
- monetize conversations
- inject advertisements

Your AI.

Your infrastructure.

Your data.