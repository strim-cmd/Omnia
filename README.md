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

> ✅ Infrastructure Sprint 1 — complete (DES-010 ratified; issues #22-#31 closed)

Current sprint:

> 🚧 Domain Sprint 2 — planned (milestone #5)

The OmniaFoundation, OmniaDomain, and OmniaInfrastructure packages are implemented against their frozen contracts (DES-001..DES-010), with the three package test suites green (503 tests). Domain Sprint 2 extends the Domain capability contract (DES-009 v0.3.0) so the concrete provider capabilities can be implemented in Infrastructure Sprint 2 (DES-010 v1.1.0).

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