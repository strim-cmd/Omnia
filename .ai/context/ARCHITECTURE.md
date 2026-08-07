# Architecture Context

Working summary of the Omnia architecture. The authoritative architecture documents live in `Documentation/Architecture/` and take precedence over this summary.

Status: Architecture Foundation complete. ADR-0001 and ADR-0002 are Accepted. The architecture documents (01–06) are Draft. No production code exists yet.

## Source Documents

- `Documentation/Architecture/01_SYSTEM_OVERVIEW.md`
- `Documentation/Architecture/02_LAYERED_ARCHITECTURE.md`
- `Documentation/Architecture/03_MODULE_MODEL.md`
- `Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md`
- `Documentation/Architecture/05_LOCAL_STORAGE_ARCHITECTURE.md`
- `Documentation/Architecture/06_DEPENDENCY_INJECTION.md`
- `Documentation/Architecture/ADR/ADR-0001-architectural-style.md`
- `Documentation/Architecture/ADR/ADR-0002-dependency-direction.md`

## Layers

Omnia follows a strict layered architecture. Dependencies point inward only.

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

Defined in ADR-0002. Allowed dependencies:

- Presentation → Application
- Application → Domain
- Infrastructure → Domain (implements Domain contracts)
- Infrastructure → Foundation
- Application → Foundation (shared utilities only, when justified)

Forbidden dependencies include Presentation → Infrastructure, Presentation → Persistence, Domain → SwiftUI, Domain → SQLite, Domain → URLSession, and Infrastructure → Presentation.

## Layer Responsibilities

- **Presentation** — SwiftUI views, screens, and user interactions. No business logic.
- **Application** — use cases, application services, and orchestration of user flows.
- **Domain** — business rules, entities, and provider-agnostic contracts. No platform dependencies.
- **Infrastructure** — provider adapters, networking, persistence, keychain, and platform services.
- **Foundation** — shared primitives, extensions, and pure utilities.

## Design Guidelines

- Prefer extending the existing architecture over introducing new patterns.
- Keep the project simple; reject solutions that add unnecessary complexity.
- Record significant architecture decisions as ADRs in `Documentation/Architecture/ADR/`.
- When unsure, ask instead of assuming.

## Related Documents

- `context/STACK.md`
- `standards/SWIFT.md`
- `standards/SECURITY.md`
