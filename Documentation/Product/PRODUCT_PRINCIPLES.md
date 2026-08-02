---
title: Product Principles
document_id: PRD-001
version: 0.1.0
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
  - Documentation/Product/VISION.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - .ai/AI_CONSTITUTION.md

supersedes: []

tags:
  - product
  - principles
  - decision-framework
  - requirements
---

# Product Principles

> This document defines HOW product decisions are made.
>
> Every feature and product decision MUST be consistent with these principles.

## Executive Summary

This document is the primary reference for evaluating new features and product decisions in Omnia.

It is a normative engineering document. It is not a vision document, a roadmap, or a feature list. The Vision states the aspiration; the Product Charter defines the boundaries; this document defines the decision process inside those boundaries.

The Product Charter defines WHAT Omnia is. This document defines HOW decisions are made. It is used by product owners, software engineers, designers, AI agents, and future contributors to evaluate every proposal against the same standard.

Use it at every point of product development: before a feature is proposed, during its design, and when it is reviewed. A proposal that cannot satisfy the principles is not accepted.

## Relationship to Product Charter

The Product Charter and this document serve different roles.

- The Product Charter defines WHAT Omnia is: its identity, invariants, scope, and boundaries.
- This document defines HOW decisions are made: the principles, the checklist, and the conflict rules.

The Product Charter is the authority on what can be built. This document is the authority on how to evaluate what is proposed. The two must never contradict. When a principle in this document conflicts with the Product Charter, the Product Charter wins and this document must be corrected.

## Guiding Principles

Each principle states its statement, its rationale, its practical implications, and its boundaries through examples and anti-examples.

### 1. User Ownership

**Statement**

The user owns all data, configuration, and decisions. Omnia owns none of it.

**Rationale**

Omnia exists so that users control their AI experience: their providers, their API keys, their conversations, their prompts, and their workflows. Omnia is the interface, not the owner. Any feature that transfers ownership to Omnia breaks the product's reason to exist.

**Practical Implications**

- User data lives on-device and is removable by the user.
- Users bring their own providers and API keys.
- No feature may require Omnia to hold, route, or manage user data.
- No feature may require an Omnia-owned account.

**Good Examples**

- API keys stored in Keychain on-device.
- Conversations stored locally.
- Multiple user-configured connections.

**Anti-Examples**

- A cloud account managed by Omnia.
- Data that cannot be exported or removed by the user.
- Features that require Omnia-owned infrastructure.

### 2. Privacy First

**Statement**

Privacy is the default behavior, not an optional feature.

**Rationale**

Omnia promises it will never collect analytics by default, proxy AI requests, store API keys remotely, monetize conversations, or inject advertisements. Privacy is the product's trust guarantee. It must hold without any configuration.

**Practical Implications**

- No telemetry, analytics, or tracking is enabled by default.
- Requests go directly from the device to the provider.
- Secrets, tokens, and conversation content are never logged.
- Privacy holds for every user, including users who change no settings.

**Good Examples**

- Direct device-to-provider requests.
- No analytics in the build.
- Credentials stored in Keychain.

**Anti-Examples**

- Telemetry enabled by default.
- Request logging that captures conversation content.
- Third-party services that observe user traffic.

### 3. Native Experience

**Statement**

Every screen and interaction should feel designed by Apple.

**Rationale**

Omnia's identity is a native Apple application. A web experience wrapped in a native shell is a failure state. Users on iOS, iPadOS, and macOS expect platform conventions, and Omnia must meet that expectation.

**Practical Implications**

- Follow the Apple Human Interface Guidelines.
- Use native SwiftUI components before custom ones.
- Respect platform conventions for each platform.
- Support VoiceOver, Dynamic Type, keyboard navigation where appropriate, high contrast, and reduced motion.

**Good Examples**

- Native SwiftUI views and navigation.
- System settings respected: dark mode, Dynamic Type, reduced motion.
- Standard platform gestures and accessibility.

**Anti-Examples**

- A WebView-based interface.
- Custom controls that replace native behavior.
- Interactions that ignore platform conventions.

### 4. Simplicity Wins

**Statement**

Every feature must justify its existence. Complexity is a liability.

**Rationale**

A feature that adds complexity without significant value must not be built. Simplicity is what keeps the codebase understandable, the interface usable, and the product maintainable over time.

**Practical Implications**

- Prefer the smallest change that satisfies the requirement.
- Reject solutions that increase complexity without measurable benefit.
- Good defaults remove the need for configuration.

**Good Examples**

- A setting that is never needed is not added.
- A feature with one clear default behavior.
- A change that removes code while preserving behavior.

**Anti-Examples**

- Configuration options that exist to compensate for missing defaults.
- Accumulating feature flags.
- Adding a feature because it is easy, not because it is needed.

### 5. Provider Independence

**Statement**

Any OpenAI-compatible endpoint can be used without changing the application.

**Rationale**

Provider independence is the core problem Omnia solves. Users are locked into ecosystems today; Omnia exists so the interface is stable and the provider is interchangeable. Losing provider independence reintroduces vendor lock-in.

**Practical Implications**

- All providers are supported through one documented interface.
- Adding a provider requires no UI redesign.
- Every provider passes the same integration tests.
- Features are not tied to a specific provider.

**Good Examples**

- A single adapter interface implemented by every provider.
- Generic provider configuration: endpoint, key, model.
- Identical behavior regardless of provider.

**Anti-Examples**

- UI that changes depending on the provider.
- Settings that exist for one provider only.
- Features that depend on a single vendor's API.

### 6. Performance Matters

**Statement**

Omnia must be fast and responsive.

**Rationale**

The interface is the product. Latency and jank are product defects. A native application that feels slow fails the product's core promise.

**Practical Implications**

- Performance is a design constraint, not a tuning step.
- Streaming responses render incrementally without blocking the interface.
- Startup performance is measured and tracked.
- Memory usage has defined budgets.

**Good Examples**

- Incremental rendering of streaming responses.
- Measured startup and tracked regressions.
- Work moved off the main thread.

**Anti-Examples**

- Blocking the interface during a request.
- Unbounded memory growth during a long conversation.
- Optimizing code before measuring a real problem.

### 7. Documentation First

**Statement**

Documentation precedes implementation. A change is complete only when its documentation is updated.

**Rationale**

Documentation is what makes a codebase maintainable and a project open to future contributors. Undocumented decisions are decisions the project cannot explain later. Documentation that lags implementation creates drift and contradiction.

**Practical Implications**

- Write the documentation before implementing the change.
- Update every document that references a changed fact.
- Never invent requirements in documentation.
- Never contradict existing documentation; fix the outdated document.

**Good Examples**

- An RFC before an architecture change.
- Documentation updated in the same change as the code.
- An ADR that records a significant decision.

**Anti-Examples**

- Code merged without documentation.
- A decision made and never recorded.
- Documents that contradict each other.

### 8. Long-Term Thinking

**Statement**

Decisions optimize for the next five years, not the next release.

**Rationale**

Omnia aims to become the reference implementation of a modern native AI workspace. That requires a codebase and a product that remain understandable and extendable after years of development.

**Practical Implications**

- Prefer extending the existing architecture over introducing new patterns.
- Record significant decisions as ADRs or RFCs.
- Reject solutions that cannot be understood by a future contributor.
- Avoid shortcuts that constrain future changes.

**Good Examples**

- Stable interfaces that outlive their first implementation.
- Recorded trade-offs for every significant decision.
- A provider contract designed to be extended.

**Anti-Examples**

- A shortcut taken to meet a deadline that becomes permanent.
- A throwaway prototype merged into production.
- A decision that satisfies today's release and blocks next year's.

## Decision Framework

Every proposed feature is evaluated against the following checklist before it is accepted.

### Checklist

- Does this solve a real user problem?
- Does it respect User Ownership?
- Does it preserve Privacy First?
- Does it introduce unnecessary complexity?
- Does it violate a Product Invariant?
- Does it require Omnia-operated infrastructure?
- Does it remain provider independent?
- Does it follow Apple's Human Interface Guidelines?
- Can it be maintained for at least five years?
- Can it be documented clearly?

### How to Use This Checklist

The checklist is mandatory. It is used at two points: before a feature is accepted, and during its review.

- Every question must be answered. An unanswered question is a rejection.
- A single failure is a rejection unless the reason is documented and accepted.
- The answers and the reasoning are recorded with the feature, so the decision is reviewable later.
- A feature that passes the checklist still requires documentation before implementation.

The checklist does not replace the Product Charter's Decision Framework. When a feature reaches the charter's checklist, the charter governs.

## Anti-Patterns

Anti-patterns are recurring mistakes that violate the principles. Recognizing them early prevents costly rework.

### Feature Creep

Adding features because they are possible or requested frequently, without evaluating each against the principles.

Why it is dangerous: It accumulates complexity, dilutes focus, and makes every future change harder. Feature creep is the product of ignoring the checklist.

### Provider-Specific UI

Building interface elements that exist for a single provider.

Why it is dangerous: It violates Provider Independence. The UI becomes coupled to one vendor, adding a provider requires UI work, and the interface stops being stable.

### Hidden Behaviour

Behavior that the user cannot predict or discover from the interface.

Why it is dangerous: It breaks trust and the Native Experience. A user must never be surprised by what the application does with their data or requests.

### Excessive Configuration

Settings that exist to compensate for missing defaults.

Why it is dangerous: Every option is a decision the user must make and a behavior the team must test. Configuration should be the exception, not the default. It violates Simplicity Wins.

### Premature Optimisation

Optimizing performance before measuring a real problem.

Why it is dangerous: It adds complexity with no measurable value, and it is usually directed at the wrong bottleneck. It violates Simplicity Wins and Performance Matters.

### Duplicate Workflows

Two ways to do the same thing in different parts of the application.

Why it is dangerous: It breaks consistency, doubles maintenance cost, and makes behavior unpredictable. The same action must always behave the same way.

### Marketing-Driven Features

Adding features because they are expected or advertised, not because they solve a user problem.

Why it is dangerous: It violates the checklist's first question. Such features rarely survive contact with real users and always add maintenance cost.

### Adding Complexity Without Measurable Value

Increasing the size of the codebase or the interface without a measurable improvement for users.

Why it is dangerous: Complexity is a liability that compounds. If the value cannot be stated in measurable terms, the complexity is unjustified.

## Conflict Resolution

Principles can conflict. When they do, the decision is evaluated explicitly and recorded.

### How to Evaluate a Conflict

1. Identify which principles conflict and state the conflict in concrete terms.
2. Apply the priority below to resolve the trade-off.
3. Prefer the option that keeps every Product Invariant intact.
4. Record the decision and the reasoning with the feature.

### Priority

When principles conflict, this order governs:

1. **User Ownership and Privacy First** — the reason Omnia exists. A violation destroys user trust and cannot be repaired.
2. **Native Experience** — the product's identity.
3. **Provider Independence** — the product's core problem.
4. **Long-Term Thinking** — the project's future.
5. **Performance Matters and Simplicity Wins** — applied as filters on every change.

### Examples

**Privacy vs Convenience**

A convenience that reduces privacy is rejected by default. Privacy First wins because it is the product's trust guarantee. The user may explicitly opt in, but the default is private.

**Performance vs Simplicity**

Complexity for the sake of performance is accepted only when it is measured, documented, and necessary. An unmeasured optimization is rejected.

**Native UX vs Cross-Provider Consistency**

Platform conventions win over provider-specific differences. Consistency means consistent behavior, not an identical interface for every provider.

## Decision Examples

Each example follows the same path: proposal, evaluation, decision, reasoning.

### Cloud Sync

**Feature Proposal**

Synchronize conversations across devices through an Omnia service.

**Evaluation**

- Requires Omnia-operated infrastructure: fails.
- Requires an Omnia-owned account: violates User Ownership.
- Requires routing user data through Omnia: violates Privacy First.

**Decision**

Rejected.

**Reasoning**

Cloud sync contradicts User Ownership, Privacy First, and the product's non-goal of owning user infrastructure. If a future version considers it, the constraint set must change first.

### Prompt Marketplace

**Feature Proposal**

A marketplace where users browse, rate, and purchase prompts.

**Evaluation**

- Fails Simplicity Wins: adds a platform, moderation, and billing.
- Requires Omnia-operated infrastructure: fails.
- Contradicts the Product Charter non-goal: Omnia is not a prompt marketplace.

**Decision**

Rejected.

**Reasoning**

The feature is a product Omnia explicitly decided not to become. It adds a platform's complexity and requires infrastructure Omnia must not operate.

### Provider-Specific Settings

**Feature Proposal**

Settings that configure behavior for one provider only, shown only when that provider is active.

**Evaluation**

- Violates Provider Independence: the interface becomes coupled to a vendor.
- Violates Simplicity Wins: adds conditional UI and behavior.
- Adding a provider would require UI changes: fails the engineering goals.

**Decision**

Rejected.

**Reasoning**

Provider-specific settings make the interface unstable. Capabilities that differ across providers must be expressed through the generic provider contract, not through conditional UI.

### Offline History

**Feature Proposal**

Conversations remain available and searchable when the device is offline.

**Evaluation**

- Respects User Ownership: data stays on-device.
- Preserves Privacy First: no infrastructure involved.
- Maintains Provider Independence: provider-agnostic.
- Simplifies the product: removes a dependency on connectivity.

**Decision**

Accepted.

**Reasoning**

Offline history strengthens every high-priority principle and requires no Omnia infrastructure. It aligns with the local-first foundation.

### Multiple Provider Support

**Feature Proposal**

Users connect several providers and choose a model per conversation.

**Evaluation**

- Respects User Ownership: users configure their own providers.
- Preserves Provider Independence: is the core requirement.
- Follows the architecture: a single provider contract.

**Decision**

Accepted.

**Reasoning**

Multiple provider support is the product's defining capability. It is consistent with every principle and with the Product Charter's success definition.

## Product Quality

A high-quality Omnia feature exhibits the following characteristics. Each characteristic is a review criterion.

### Discoverability

The feature is findable by a user who needs it, without documentation. It uses platform conventions for placement, naming, and gestures.

### Consistency

The feature behaves the same way everywhere it appears. It reuses existing components, patterns, and terminology instead of introducing new ones.

### Maintainability

The feature is simple enough to understand and extend. It follows the layered architecture, uses existing patterns, and adds no hidden state.

### Accessibility

The feature is usable with VoiceOver, Dynamic Type, keyboard navigation where appropriate, high contrast, and reduced motion. Accessibility is a requirement, not a checklist item.

### Documentation

The feature is documented before it is implemented. Its behavior, trade-offs, and decisions are recorded and consistent with related documents.

### Reliability

The feature behaves predictably, including under failure. Errors are handled explicitly, never silently, and never at the expense of user data.

## Related Documents

- `Documentation/Product/VISION.md` — the long-term aspiration.
- `Documentation/Product/PRODUCT_CHARTER.md` — the authoritative product specification.
- `.ai/AI_CONSTITUTION.md` — the governing rules for AI agents.
