---
title: ADR-0001 — Architectural Style
document_id: ADR-0001
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
  - Documentation/Architecture/ADR/ADR-0002-dependency-direction.md
  - Documentation/Product/VISION.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - Documentation/Product/PRODUCT_PRINCIPLES.md

supersedes: []

tags:
  - architecture
  - adr
---

# ADR-0001 — Architectural Style

## Status

Accepted

---

## Context

Omnia is expected to evolve for many years.

The project must remain maintainable while supporting:

- multiple AI providers;
- multiple Apple platforms;
- offline operation;
- future modules;
- open-source contributions.

The architecture must minimize coupling while maximizing testability and extensibility.

---

## Decision

Omnia adopts the following architectural approach.

### Overall Architecture

Layered Clean Architecture.

### Presentation

SwiftUI

Observation framework

Navigation

No business logic.

### Application

Use Cases.

Application Services.

Workflow orchestration.

### Domain

Pure business entities.

Protocols.

Business rules.

Policies.

No platform dependencies.

### Infrastructure

Repositories.

Provider implementations.

Persistence.

Networking.

Keychain.

File System.

### Foundation

Utilities.

Configuration.

Logging.

Shared abstractions.

---

## Dependency Rule

Dependencies always point inward.

Allowed dependencies:

- Presentation → Application
- Application → Domain
- Infrastructure → Domain (implements Domain contracts)
- Infrastructure → Foundation
- Application → Foundation (shared utilities only, when justified)

No layer may bypass another layer.

---

## Consequences

Advantages

- Highly testable
- Easy provider replacement
- Long-term maintainability
- Independent business logic
- Clear ownership

Trade-offs

- More abstractions
- More protocols
- Slightly slower initial development

The trade-off is accepted because Omnia prioritizes long-term maintainability over rapid feature delivery.

---

## Rationale

The architecture reflects the Product Principles.

It supports:

- Provider Independence
- Documentation First
- Long-Term Thinking
- Privacy First

without coupling the system to any specific AI provider or platform implementation.

---

## Related ADRs

- ADR-0002 — Dependency Direction

---

## Related Documents

- `Documentation/Product/VISION.md`
- `Documentation/Product/PRODUCT_CHARTER.md`
- `Documentation/Product/PRODUCT_PRINCIPLES.md`