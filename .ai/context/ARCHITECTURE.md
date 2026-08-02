# Architecture Context

Working summary of the Omnia architecture. The authoritative architecture documents live in `Documentation/Architecture/` (not yet populated).

Status: Draft. No production code exists yet (Sprint 0).

## Layers

Omnia follows a strict layered architecture. Dependencies point downward only.

```text
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

## Dependency Rules

- A layer may depend only on the layer directly below it.
- Upward and skip-level dependencies are forbidden.
- The Domain layer must not depend on UI or platform frameworks.
- Native Apple frameworks are preferred over third-party dependencies.

## Layer Responsibilities

- **Presentation** — SwiftUI views, screens, and user interactions.
- **Application** — use cases and orchestration of user flows.
- **Domain** — business rules, entities, and provider-agnostic contracts.
- **Infrastructure** — provider adapters, networking, persistence, and platform services.
- **Foundation** — shared primitives, extensions, and pure utilities.

These definitions are the working model until `Documentation/Architecture/` is populated.

## Design Guidelines

- Prefer extending the existing architecture over introducing new patterns.
- Keep the project simple; reject solutions that add unnecessary complexity.
- Record significant architecture decisions in `Documentation/ADR/`.
- When unsure, ask instead of assuming.

## Related Documents

- `context/STACK.md`
- `standards/SWIFT.md`
- `standards/SECURITY.md`
