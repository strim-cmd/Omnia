---
title: Environment API
document_id: DES-006
version: 0.1.0
status: Draft
owner: Founder
project: Omnia
authors:
  - Founder
reviewers:
  - Chief Architect
created: 2026-08-03
last_updated: 2026-08-03
related_documents:
  - Documentation/Design/FOUNDATION_API.md
  - Documentation/Design/API/API_DESIGN_GUIDELINES.md
  - Documentation/Design/API/IDENTIFIER_API.md
  - Documentation/Design/API/CLOCK_API.md
  - Documentation/Design/API/LOGGER_API.md
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - .ai/standards/SWIFT.md
  - .ai/standards/TESTING.md
supersedes: []
tags:
  - design
  - foundation
  - environment
  - api-specification
  - specification
  - engineering
---

# Environment API

> This document defines the canonical Environment abstraction used across Omnia: its purpose, its API contract, its ownership, its design rules, and its usage guidelines. It intentionally avoids implementation.

## 1. Purpose

Omnia defines its own Environment abstraction instead of letting consumers read process-wide globals, platform environment APIs, or scattered runtime state directly. Platform-aware behavior must be decided without coupling the Domain or Application layers to a specific platform (DES-001 §3.3); the Environment is the mechanism that satisfies that requirement.

A single canonical abstraction exists for four reasons:

- **It makes runtime facts a declared dependency.** Process-wide globals and platform environment APIs are hidden dependencies: reachable by lookup, never injectable, and impossible to control in a test (ARC-006). The Environment turns runtime facts into a value that is delivered, owned, and replaceable.
- **It makes platform facts testable.** Scattered runtime state cannot be controlled, so behavior that reads it is nondeterministic and order-dependent. Deterministic behavior requires that external state be injected or isolated (DES-001 §5, ARC-001); the Environment is the mechanism for runtime state.
- **It gives runtime facts one type and one owner.** Each consumer that reads the platform directly re-derives facts with a different representation and no verification. The Environment centralizes the facts as typed values, so every layer shares one source of truth (DES-001 §3.3).
- **It keeps the platform out of the layers.** The product targets iOS, iPadOS, and macOS (PRODUCT_CHARTER), but no Domain or Application consumer references a platform type or platform API. The Environment captures the platform as domain-agnostic facts; consumers decide behavior from facts, never from platform calls.

The Environment is immutable information describing the execution environment. It is explicitly NOT an execution context, a dependency container, a service locator, a configuration store, or a lifecycle manager. Those are different concerns, owned elsewhere, and a consumer that needs them must not reach for the Environment.

The abstraction is not a convenience; it is the enforcement of the runtime-information boundary the architecture requires.

## 2. Design Goals

The abstraction is designed to satisfy the following goals. Each goal is a normative requirement of the API and is verified by the tests in Section 7.

- **Immutable.** The Environment is fixed at construction and never changes during execution. A change to the environment is a new Environment, never a mutation (ARC-001, SWIFT.md).
- **Explicit.** Every fact is a declared value. Nothing is hidden, derived on the fly, or reached by lookup.
- **Strongly typed.** Every value has a type. Platform facts, execution mode, and capabilities are typed, never raw strings or unverified platform reads (ARC-002).
- **Platform-independent.** The descriptor is domain-agnostic. The platform is captured as facts; consumers never reference a platform type or platform API (DES-001 §3.3).
- **Injectable.** Environments are delivered by composition. No consumer constructs, acquires, caches, or replaces the Environment it receives (ARC-006).
- **Testable.** Construction is deterministic; tests build exact Environments and assert behavior against them.
- **Minimal surface.** The contract exposes exactly the elements of Section 3 and no more (ARC-008).

## 3. Public API

The public API is conceptual. It specifies what the abstraction provides, not how it is provided.

| Element | Definition |
|---|---|
| Environment | An immutable, value-typed descriptor of the execution environment. It is a fixed set of runtime facts, domain-agnostic, with no product meaning. Consumers receive it by composition and never mutate or construct it. |
| Environment values | The individual facts the Environment reports. Each value is typed, immutable, and deterministic, and each describes a runtime characteristic of the environment and nothing else. |
| Platform characteristics | The domain-agnostic facts about the native platform: the platform family and its version. They name the platform and its version without referencing a platform API (DES-001 §3.3). |
| Execution mode | A factual description of how the process is running. It is a runtime characteristic, never a configuration decision and never a product decision. |
| Capabilities | The domain-agnostic facts about what the runtime environment can do. Environment capabilities are facts about the environment; they are distinct from provider capabilities, which are provider concepts owned elsewhere (ARC-004). |
| Feature availability | The environment's answer to whether a runtime capability is available, determined from the platform characteristics and execution mode. It reports availability as a fact; product decisions are made by consumers, never by the Environment. |

Normative statements:

- The API MUST expose exactly the elements above and no more.
- The Environment is immutable: its values never change during execution (ARC-001). A change to the environment is a new Environment, never a mutation.
- The Environment MUST NOT provide execution context, a dependency container, a service locator, a configuration store, or a lifecycle manager.
- The Environment describes runtime characteristics only; it carries no business, feature, provider, storage, UI, or configuration content (DES-001 §2).
- Environment values are typed; the API exposes no raw, untyped platform facts.
- Equality is defined by content: two Environments with identical values are equal, and two Environments that differ in any value are not.
- Consumers never read process-wide globals or platform environment APIs; the Environment is the only path to runtime facts.

## 4. Ownership

- **Who owns the abstraction.** OmniaFoundation owns the Environment descriptor. It is the shared, domain-agnostic description of the execution environment, with no product meaning (DES-001 §3.3).
- **Who creates an Environment.** Only composition creates an Environment. The Composition Root constructs the production Environment once from platform facts supplied by the platform owner — OmniaInfrastructure — for the application lifetime; tests construct deterministic Environments of their own. No consumer constructs an Environment (ARC-006).
- **Who injects it.** Environments are delivered by composition. Every consumer that needs runtime facts declares an Environment and receives it; nothing acquires one by lookup or from global state (ARC-006).
- **Who consumes it.** OmniaInfrastructure (platform services), OmniaApp (startup and capability checks), and any consumer that needs native-context awareness without UI coupling (DES-001 §3.3).
- **Who is allowed to extend it.** Only OmniaFoundation extends the Environment contract. Adding a value is an additive change owned by the Foundation module and documented before use. Consumers read values; they never extend the set (ARC-007, ARC-008).

## 5. Usage Rules

- **Environment is immutable.** Never mutate an Environment during execution; a change is a new Environment (ARC-001).
- **Never use Environment as a service locator.** The Environment delivers facts, not dependencies (ARC-006).
- **Never hide dependencies inside Environment.** Dependencies are injected separately; the Environment never carries them (ARC-006).
- **Environment describes runtime characteristics only.** It never carries configuration values, credentials, product state, or business content.
- **Read values; never construct or cache.** Consumers receive the Environment and read its values; they never construct, cache, or replace it.
- **Never read process-wide globals or platform environment APIs in consumer code.** The Environment is the only path to runtime facts.
- **Never branch on the Environment's presence as a mechanism.** The Environment is a fact source, not a behavior switch.

## 6. Architectural Constraints

- **No business logic.** The Environment carries no business, feature, or product content (DES-001).
- **No dependency injection container.** The Environment is never a container, a locator, or a composition mechanism (ARC-006).
- **No logger implementation.** The Environment is not a logger; logging is consumed through the Logger interface (DES-005).
- **No provider implementation.** The Environment knows nothing about providers and never references provider concepts (ARC-004).
- **No persistence.** The Environment stores nothing and performs no storage (ARC-005).
- **No networking.** The Environment performs no network access.
- **No mutable state.** The Environment is immutable; it holds no state that changes during execution (ARC-001).
- **No configuration values.** Configuration is owned by the Configuration module and consumed through its primitive; the Environment never carries configuration (DES-001 §3.4).
- **No credentials.** Credential and secret content is owned by Authentication and never enters the Environment (ARC-001).
- **No product meaning.** The abstraction lives in the Foundation position and carries no product content (DES-001).
- **No Omnia package dependency.** The abstraction sits at the bottom of the dependency graph and introduces no dependency on any Omnia package (ARC-002, ADR-0002).
- **Platform dependency only where justified.** The platform MAY be relied on only to capture platform facts at construction, and the dependency MUST NOT leak to consumers (DES-001).
- **No UI concerns.** The Environment carries no user interface or presentation state.

## 7. Testing Requirements

The abstraction MUST be verified by behavioural tests. The required tests cover:

- **Immutability** — after construction, the Environment's values never change; repeated reads are identical, and no operation mutates the Environment (ARC-001).
- **Deterministic construction** — constructing an Environment from a fixed set of facts always yields the same values; construction depends on no external state — no wall clock, no network, no process-wide globals, and no order of other tests (DES-001 §5).
- **Equality semantics** — two Environments with identical values are equal; two that differ in any value are not; comparison is deterministic and consistent (ARC-001).
- **Injection** — a consumer receives the Environment by composition and behaves identically under a test-provided Environment; the Environment is replaceable without changing the consumer (ARC-006).
- **Predictable behaviour across platforms** — behavior driven by Environment facts is identical for identical facts on any platform; the platform is captured only as facts and never reaches consumer logic (DES-001 §3.3).

Every test MUST be deterministic and independent (TESTING.md, ARC-001).

## 8. Future Evolution

New environment values are added without breaking compatibility:

- **Additive values.** A new environment value is a new element; existing values keep their meaning, their types, and their behavior. The descriptor is additive; new platform facts are added without changing existing facts (DES-001 §3.3).
- **Justified addition.** A value is added only when an existing architectural requirement justifies it, and it is documented before use (DES-004, PRODUCT_PRINCIPLES — Documentation First).
- **No contract change.** Adding a value never changes the core contract or the semantics of existing values; consumers that do not read the new value are unaffected.
- **Owned by OmniaFoundation.** Every value is added by the owner of the contract; consumers never extend the set (ARC-007).

The Environment remains an immutable, additive descriptor; it grows by extension, never by modification.

## Related Documents

- `Documentation/Design/FOUNDATION_API.md` — the OmniaFoundation public API contract this document realizes.
- `Documentation/Design/API/API_DESIGN_GUIDELINES.md` — the standard this specification must satisfy.
- `Documentation/Design/API/IDENTIFIER_API.md` — the canonical Identifier abstraction, whose conventions this document follows.
- `Documentation/Design/API/CLOCK_API.md` — the Clock abstraction, a sibling primitive.
- `Documentation/Design/API/LOGGER_API.md` — the Logger interface, a sibling primitive.
- `Documentation/Architecture/07_MODULE_STRUCTURE.md` — the modules that consume environment facts and the Foundation module that owns the descriptor.
- `Documentation/Architecture/08_PACKAGE_MODEL.md` — the package model, stability, and boundary rules.
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` — OmniaFoundation's responsibilities and dependencies.
- `.ai/standards/SWIFT.md` — concurrency and value-semantics rules.
- `.ai/standards/TESTING.md` — deterministic, independent tests.
