---
title: Product Charter
document_id: PRD-000
version: 0.2.0
status: Draft

owner: Founder
project: Omnia

authors:
  - Founder

reviewers:
  - Chief Architect

created: 2026-08-02
last_updated: 2026-08-02

related_documents:
  - README.md
  - Documentation/Product/VISION.md

supersedes: []

tags:
  - product
  - charter
  - specification
  - vision
  - strategy
---

# Product Charter

> This document is the authoritative product specification for the Omnia project.
>
> It defines the product's identity, invariants, scope, and direction.
>
> Every significant product or architectural decision MUST be consistent with this document.

---

# Executive Summary

Omnia is a native AI workspace designed exclusively for Apple's platforms.

The application is not an AI provider.

It is not another chatbot.

It is not a cloud platform.

Instead, Omnia provides a beautiful, secure, and high-performance interface that allows users to work with any OpenAI-compatible AI provider through a single native application.

The project is built around a simple idea:

> Users should own their AI experience.

That includes:

- their providers;
- their API keys;
- their conversations;
- their prompts;
- their workflows.

Omnia never attempts to become the center of the user's AI ecosystem.

Instead, it becomes the best interface to it.

---

# Purpose

The purpose of Omnia is to remove friction from interacting with modern AI systems.

Today users often need different applications for different providers.

For example:

- ChatGPT for OpenAI
- Claude for Anthropic
- Gemini for Google
- LM Studio for local models
- Ollama for self-hosted models
- OpenRouter for multi-provider routing

Each application has:

- different user interfaces;
- different shortcuts;
- different capabilities;
- different workflows.

Omnia solves this problem by providing one consistent native experience regardless of the selected provider.

---

# Mission

Build the best native AI client for Apple platforms.

Not the largest.

Not the most feature-rich.

The best.

The application should feel like software designed specifically for macOS, iPadOS, and iOS—not a web application wrapped in a native shell.

Every interaction should respect Apple's Human Interface Guidelines while remaining provider-independent.

---

# Vision

Omnia aims to become the reference implementation of a modern native AI workspace.

Users should be able to switch providers in seconds without changing their workflow.

Developers should be able to add support for new providers without redesigning the application.

The architecture should remain maintainable for many years, allowing the project to evolve without accumulating unnecessary complexity.

---

# Relationship to Vision

The Vision describes the long-term aspiration: what Omnia aims to become.

This Product Charter translates that aspiration into engineering constraints and product decisions.

The Vision is the destination. The Product Charter is the rulebook for reaching it.

When uncertainty exists, the Product Charter governs implementation decisions while remaining consistent with the Vision.

Conflicts are resolved in favor of the Charter's constraints and reported so the Vision can be updated if the aspiration has changed.

---

# Core Problem

The current AI ecosystem is fragmented.

Users are forced to choose between ecosystems rather than interfaces.

Changing providers often means changing applications, habits, shortcuts, and workflows.

This creates unnecessary friction and increases vendor lock-in.

Omnia separates the user interface from the AI provider.

The application becomes stable.

The provider becomes interchangeable.

---

# Success Definition

Omnia is considered successful when users no longer think about which provider they are using.

Instead, they simply choose the model that best fits their current task while remaining inside the same application.

The interface becomes permanent.

The provider becomes replaceable.

---

# Product Identity

Omnia is a native AI workspace for Apple platforms: iOS, iPadOS, and macOS.

It is a client for OpenAI-compatible APIs. It is not an AI provider, a subscription service, or a cloud platform.

Omnia's identity rests on one idea: the interface is stable, the provider is interchangeable.

Users own their AI experience — their providers, their API keys, their conversations, their prompts, their workflows. Omnia owns none of it.

Omnia exists because the AI ecosystem is fragmented. Its role is to be the stable interface to that ecosystem, not another competing application within it.

---

# Core Values

Core values govern every product decision. Each value states what it means and what it demands in practice.

## User Ownership

Description: The user owns all data, configuration, and decisions. Omnia owns none of it.

Practical implication: No feature may require Omnia to hold, route, or manage user data. User data remains on-device and is removable by the user.

## Privacy by Default

Description: Privacy is the default behavior, not an optional feature.

Practical implication: No telemetry, analytics, or tracking is enabled by default. Data collection, when it exists, is explicit and opt-in.

## Native Experience

Description: Every screen and interaction should feel designed by Apple.

Practical implication: Features must follow the Apple Human Interface Guidelines and use native SwiftUI components. A web experience wrapped in a native shell is a failure state.

## Performance

Description: Omnia must be fast and responsive.

Practical implication: Performance is a design constraint, not a tuning step. Each feature must account for its cost on every supported platform.

## Long-Term Maintainability

Description: Decisions optimize for the next five years, not the next release.

Practical implication: Code that is hard to understand or extend is rejected even when it is faster to write.

## Simplicity

Description: Every feature must justify its existence.

Practical implication: A feature that adds complexity without significant value must not be built.

---

# Design Principles

Design principles govern every future UI and UX decision. Each principle states what it requires and why.

## Native First

Use Apple's platform conventions before inventing custom behavior.

Why: Native conventions are already familiar to users, are maintained by Apple, and keep the application feeling native to the platform.

## Progressive Disclosure

Advanced functionality should remain available without overwhelming new users.

Why: It keeps the primary experience simple while preserving power for experienced users.

## Consistency

The same action should always behave the same way throughout the application.

Why: Predictability reduces the learning cost and prevents errors.

## One Primary Action

Each screen should have one obvious primary action.

Why: A single clear action focuses the user and removes decision fatigue.

## Accessibility

Accessibility is a product requirement.

Omnia must support VoiceOver, Dynamic Type, keyboard navigation where appropriate, high contrast, and reduced motion.

Why: Accessibility is not optional. Every user must be able to use the product, and supporting platform accessibility features is part of a native experience.

---

# Product Invariants

Product invariants are permanent rules. They cannot be changed by feature requests, deadlines, or convenience. Every invariant states why it exists.

## Omnia never owns user API keys

API keys belong to the user and are stored on-device in Keychain.

Why it exists: Owning keys creates liability, a target for attackers, and a dependency on Omnia-owned infrastructure. The user's credentials must remain under the user's control.

## Omnia never proxies AI traffic

Requests go directly from the device to the provider.

Why it exists: Proxying would expose conversation content to Omnia-owned infrastructure, break privacy guarantees, and add a point of failure between the user and their provider.

## Omnia remains provider-independent

Any OpenAI-compatible endpoint can be used without changing the application.

Why it exists: Provider independence is the core problem the product solves. Losing it reintroduces vendor lock-in.

## Omnia is native-first

Apple's frameworks are preferred over third-party libraries.

Why it exists: Native APIs provide the best platform integration, security, and long-term maintenance.

## Omnia is privacy-first

Privacy is the default behavior.

Why it exists: Omnia promises it will never collect analytics by default, store keys remotely, monetize conversations, or inject advertisements. Privacy-first is what keeps those promises possible.

## Omnia stores user data locally whenever possible

Conversations and connections live on the device.

Why it exists: Local storage keeps user data under user control and lets the product work without Omnia-owned infrastructure.

---

# Product Goals

Goals are grouped by type. Each goal is stated so that completion is verifiable.

## Engineering Goals

- Complete the product foundation: product documents, architecture, and development standards.
- Establish a documented provider contract and process for adding a new provider without redesigning the application.
- Keep the codebase understandable and maintainable after years of development.

## Product Goals

- Ship the first production release for iOS, iPadOS, and macOS.
- Deliver the core feature set: multiple providers, OpenAI-compatible API, streaming responses, Markdown rendering, code highlighting, local conversation storage, multiple conversations, and multiple connections.
- Deliver the planned capabilities: attachments, vision models, voice, prompt library, workspaces, and plugins.

## Community Goals

- Grow a community of contributors able to review and maintain the codebase.

## Long-Term Goals

- Become the reference implementation of a modern native AI workspace.
- Reach the point where users choose models, not applications.

---

# Product Non-Goals

Non-goals are explicit boundaries. They describe what Omnia will never become, even when a capability is technically possible.

- **An AI provider.** Omnia will not train, host, or serve models.
- **A subscription service.** Omnia will not manage billing or plans.
- **A cloud platform or proxy.** Omnia will not route or aggregate traffic between providers.
- **A social network.** Omnia will not add feeds, profiles, or social features.
- **A productivity suite.** Omnia will not become a general-purpose documents, notes, or collaboration tool.
- **A prompt marketplace.** Omnia will not broker, sell, or rank prompts.
- **An analytics or advertising platform.** Omnia will not monetize user data or attention.

---

# Target Audience

## Primary Users

- Developers and technical users who work with multiple AI providers.
- Users who self-host models (for example, Ollama, LM Studio, LocalAI, vLLM) and need a polished client.
- Privacy-conscious users who want their conversations and keys to remain on-device.

## Secondary Users

- Professionals who use AI as part of their workflow and value a consistent native interface across providers.
- Apple platform users who expect applications to follow platform conventions.

## Who Is Not the Target User

- Users who expect a hosted, sign-up-and-go AI service. Omnia requires the user to bring their own provider and API key.
- Users who want a bundled model or built-in subscription. Omnia is not a provider.
- Users who need collaboration, sharing, or cloud sync features.

---

# Decision Framework

Every proposed feature is evaluated against this checklist before it is accepted. A feature must satisfy every question to proceed.

## Feature Checklist

- Does it solve a real user problem?
- Does it violate a Product Invariant? If yes, the feature is rejected.
- Does it increase complexity? If yes, the added complexity must be justified by clear value.
- Does it improve long-term maintainability?
- Can it work without Omnia servers? A feature that depends on Omnia-owned infrastructure is rejected by default.
- Does it respect the Apple Human Interface Guidelines?
- Would this feature still make sense in five years?
- Is it consistent with the Product Charter and Vision?

## Acceptance Rule

A feature that fails any checklist question is not accepted. A feature that passes every question still requires documentation before implementation.

---

# Product Scope

## In Scope

- A native client for OpenAI-compatible APIs on iOS, iPadOS, and macOS.
- Streaming responses and Markdown rendering with code highlighting.
- Local conversation and connection storage.
- Multiple providers, connections, and conversations.
- On-device credential storage in Keychain.

## Out of Scope

- Hosting or serving models.
- Managing accounts, billing, or subscriptions.
- Proxying or routing AI traffic.
- Cloud sync, collaboration, or sharing.

## Future Considerations

- Planned capabilities listed under Product Goals. They are not in scope until specified.

---

# Success Metrics

Success is measured across four dimensions. Metrics state measurable outcomes, not marketing claims.

## Technical

- The application runs correctly on iOS, iPadOS, and macOS.
- Streaming responses render incrementally without blocking the interface.
- Tests pass in CI before every merge.
- Provider adapters implement one documented interface.
- Every provider passes the same integration tests.
- Adding a new provider requires no UI redesign.
- Startup performance is measured and tracked.
- Memory usage has defined budgets.

## UX

- Users can switch providers without changing their workflow.
- Provider switching requires minimal user interaction.
- Conversation history remains searchable.
- Every screen follows platform conventions and the design system.
- Common actions are reachable without unnecessary navigation.

## Product

- The In Scope capabilities in this document are implemented.
- Planned capabilities are delivered or explicitly re-scoped.
- No Product Invariant has been violated.

## Community

- Contributors can review and maintain the codebase without tribal knowledge.
- Contribution guidelines and the RFC process are followed.
- Security issues are reported and handled through the documented process.
- Documentation coverage remains complete.
- Every architectural decision has an ADR or RFC.
- New contributors can complete onboarding using repository documentation only.

---

# Risks

The major risks to Omnia's success, with their impact and mitigation.

## Provider API Fragmentation

Risk: OpenAI-compatible endpoints diverge, making provider integration and maintenance harder over time.

Impact: Higher maintenance cost and slower support for new providers.

Mitigation: Keep a single provider contract, isolate adapters in the Infrastructure layer, and document the integration process.

## Feature Creep

Risk: Unbounded features accumulate, the product loses focus, and complexity grows.

Impact: Declining maintainability and a product that no longer justifies each feature.

Mitigation: Apply the Decision Framework to every feature and enforce the Definition of Done.

## Small Contributor Base

Risk: The project depends on a few contributors.

Impact: Progress slows and maintenance becomes a bottleneck.

Mitigation: Keep the codebase simple, document the standards, and make onboarding explicit.

## Privacy Regressions

Risk: A violation of a privacy promise destroys user trust.

Impact: The product loses its reason to exist.

Mitigation: Treat privacy as a Product Invariant, require explicit review for security-sensitive changes, and avoid analytics by default.

## Platform Dependency

Risk: Reliance on a single platform exposes the project to platform changes.

Impact: Platform policy or API changes can disrupt the product.

Mitigation: Follow Apple's Human Interface Guidelines, prefer native APIs, and keep the Domain layer independent of UI frameworks.

---

# Long-Term Direction

In five years, Omnia is measured by the standard set in the Vision: users choose models, not applications.

Omnia remains a client, not a platform. It owns nothing: no models, no accounts, no conversations, no data. Its value is the quality of the interface between people and AI.

The codebase is still simple enough that a new contributor understands it quickly and a new provider integrates without redesign.

Omnia's philosophy in five years is the same as today: user ownership, privacy by default, native experience, and long-term maintainability.

---

# Release Philosophy

Omnia ships in small, incremental releases.

Small releases keep each change reviewable, testable, and reversible. A regression is traceable to a single change instead of a rewrite.

Large rewrites discard working behavior, invalidate testing, and make review difficult. Omnia does not plan for them.

Incremental releases follow the workflow: issue, branch, implementation, pull request, review, merge. Each release is a small step that keeps the product always releasable.

The long-term goal is a codebase that remains understandable after years of development. Small, frequent, well-documented changes are how that goal is reached.
