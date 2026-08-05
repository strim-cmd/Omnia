---
title: ADR-0002 — Dependency Direction
document_id: ADR-0002
version: 0.1.0
status: Accepted

owner: Founder
project: Omnia

authors:
  - Founder

reviewers:
  - Chief Architect

created: 2026-08-02
last_updated: 2026-08-02

related_documents:
  - Documentation/Architecture/ADR/ADR-0001-architectural-style.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - Documentation/Product/PRODUCT_PRINCIPLES.md
  - .ai/standards/SWIFT.md

supersedes: []

tags:
  - architecture
  - adr
  - dependencies
---

# ADR-0002 — Dependency Direction

This ADR defines the dependency rules for the entire project.

## Status

Accepted

---

## Context

Omnia is expected to evolve for many years.

Uncontrolled dependencies create architectural erosion over time.

The project must prevent cyclic dependencies and preserve clear ownership between layers.

The dependency rule must hold as the codebase grows, as providers are added, and as open-source contributions arrive.

---

## Problem

Unrestricted dependencies cause:

- tight coupling between layers;
- business logic leaking into the UI;
- difficult testing;
- provider-specific code spreading across modules;
- architectural drift.

Without a written rule, these problems accumulate gradually and become expensive to reverse.

---

## Decision

Dependencies always point inward.

Dependencies point inward through the allowed dependencies listed below.

A layer never bypasses another layer, and no layer imports a layer above it.

---

## Dependency Rule

```text
Presentation → Application
Application → Domain
Infrastructure → Domain (implements Domain contracts)
Infrastructure → Foundation
Application → Foundation (shared utilities only, when justified)
```

Dependencies always point inward. Infrastructure implements the Domain contracts and depends on Foundation. Application may depend on Foundation for shared utilities only, when justified.

Layer responsibilities:

- **Presentation** — SwiftUI views, screens, and user interactions. No business logic.
- **Application** — use cases, application services, and orchestration of user flows.
- **Domain** — business rules, entities, and provider-agnostic contracts. No platform dependencies.
- **Infrastructure** — provider adapters, networking, persistence, keychain, and platform services.
- **Foundation** — shared primitives, extensions, and pure utilities.

---

## Allowed Dependencies

- Presentation → Application
- Application → Domain
- Infrastructure → Domain (implements Domain contracts)
- Infrastructure → Foundation
- Application → Foundation — shared utilities only, when justified

---

## Forbidden Dependencies

Each forbidden dependency includes why it is forbidden.

- **Presentation → Infrastructure** — the UI reaches into providers, networking, and persistence directly, duplicating application logic and bypassing use cases.
- **Presentation → Persistence** — the UI reads and writes storage directly, skipping use cases and validation, and coupling views to storage formats.
- **Domain → SwiftUI** — business logic becomes tied to a UI framework and untestable outside the platform.
- **Domain → SQLite** — business rules depend on a concrete storage implementation instead of an abstraction.
- **Domain → URLSession** — business rules perform networking directly, coupling the Domain to a platform API and bypassing the provider contract.
- **Infrastructure → Presentation** — a lower layer reaching upward creates a cycle in intent and couples infrastructure to the UI.
- **Infrastructure → ViewModels** — infrastructure must never drive UI state; that responsibility belongs to Application.
- **Providers → Views** — provider implementations must never reference views or render UI; they implement a contract only.
- **Business Logic → SwiftUI** — placing business rules in views couples logic to the UI and prevents reuse and testing.

---

## Examples

Good examples show the rule working. Bad examples show the failure mode and why it matters.

### Good: Chat Screen

The view (Presentation) calls a use case (Application). The use case depends on a repository protocol (Domain). The repository implementation (Infrastructure) performs the request.

Why it works: the view never sees the provider, the network layer, or the storage layer. Each layer stays replaceable and testable in isolation.

### Good: Provider Switching

The Domain defines a provider contract. Each provider is an implementation in Infrastructure.

Why it works: replacing a provider changes Infrastructure only. The UI and the business logic are untouched, which is the product's Provider Independence requirement.

### Good: Streaming Response

A streaming provider implementation in Infrastructure exposes an async sequence through the Domain contract. Application forwards it, and the view renders incrementally.

Why it works: the streaming concern stays in Infrastructure, and every layer consumes it through the abstraction.

### Bad: View Calls URLSession

A view creates a URLSession request directly.

Why it fails: the UI is coupled to networking, application logic is duplicated, and the request cannot be tested without the network.

### Bad: Domain Imports SwiftUI

A domain entity imports SwiftUI.

Why it fails: business logic is coupled to the UI framework, cannot run in a headless test, and drags UI concerns into every layer that uses it.

### Bad: View Writes to Persistence

A view stores conversation rows directly.

Why it fails: storage format and validation leak into the UI, persistence is bypassed, and changing storage requires UI changes.

### Bad: Infrastructure Imports Views

An infrastructure component constructs or references a view.

Why it fails: the dependency graph turns upward, creating a cycle in intent and coupling platform services to the UI.

---

## Alternatives Considered

### Fully Layered Architecture

Strict layers where every interaction passes through a formal interface at every boundary, with no shared utility access.

Why it was rejected: it maximizes structure but adds the highest abstraction and boilerplate cost before the module structure justifies it. The chosen rule keeps the same discipline with less ceremony.

### Feature-First Without Architectural Boundaries

Modules organized by feature with unrestricted dependencies.

Why it was rejected: business logic leaks into the UI, provider-specific code spreads across modules, testing becomes hard, and architectural drift follows.

### Classic MVVM

View models as the central organizing unit, owning business behavior.

Why it was rejected: business logic ends up coupled to the presentation framework, which weakens testability and Provider Independence.

---

## Consequences

Benefits

- easier testing;
- modularity;
- provider independence;
- maintainability.

Trade-offs

- more protocols;
- additional abstractions;
- slightly more boilerplate.

The trade-off is accepted because Omnia prioritizes long-term maintainability over rapid feature delivery.

---

## Rationale

The dependency rule supports the Product Principles.

- **Privacy First** — data access and secrets are confined to Infrastructure (Keychain, networking) and never reach Presentation or Domain.
- **Provider Independence** — providers implement a single Domain contract behind an abstraction, so swapping providers never touches upper layers.
- **Documentation First** — each dependency is explicit and recorded, and the rule itself is the reference that reviews use.
- **Long-Term Thinking** — the rule prevents architectural erosion and keeps the codebase maintainable over years of development.

---

## Future Enforcement

Architecture fitness functions define automated checks that must hold.

- **Domain must never import SwiftUI.**
- **Presentation must never access persistence directly.**
- **Infrastructure must never reference Views.**
- **Every Provider implements the same protocol.**

These rules are verified during code review today. They may later be enforced automatically in CI with dependency-check tooling and module boundaries.

---

## Related ADRs

- ADR-0001 — Architectural Style

---

## Related Documents

- `.ai/standards/SWIFT.md`
- `Documentation/Product/PRODUCT_CHARTER.md`
- `Documentation/Product/PRODUCT_PRINCIPLES.md`
