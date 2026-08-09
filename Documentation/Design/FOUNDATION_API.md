---
title: OmniaFoundation Public API Contract
document_id: DES-001
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
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - Documentation/Product/PRODUCT_PRINCIPLES.md
  - project Swift standards
supersedes: []
tags:
  - design
  - foundation
  - api-specification
  - specification
  - engineering
---

# OmniaFoundation Public API Contract

> This document is the normative engineering specification of the public API surface of the OmniaFoundation package.
>
> It defines WHAT the package exposes — the contract its consumers depend on. It intentionally does NOT specify implementation.

## 1. Purpose

OmniaFoundation is the bottom of the Omnia dependency graph (ARC-002, ADR-0002). It exists to provide reusable, implementation-independent primitives shared across the workspace: pure utilities, logging primitives, configuration primitives, and shared abstractions with no product meaning (ARC-009).

Every package above it depends on it; nothing depends on any package above it. Because it is depended on by everything, its public API is a contract held by the whole system. A change to that contract propagates silently to every consumer, so the contract is defined here — before any implementation begins — and changes only through a deliberate process.

This document specifies the initial public API inventory, the design principles that govern it, the dependency rules that constrain it, the rules by which it evolves, and the ordered sequence in which it is implemented.

The specification governs the package alone. It defines no behavior of the Domain, Application, Infrastructure, Presentation, or application shell layers; those are specified by their own documents.

## 2. Package Responsibilities

### 2.1 What Belongs in OmniaFoundation

OmniaFoundation owns domain-agnostic primitives and nothing else. The following belong in the package:

- pure utility functions with no product meaning;
- the logging interface (protocols only, never implementations of a platform logger);
- configuration primitives (typed value access with defaults, without persistence and without product decisions);
- a stable identifier primitive for domain identity;
- a generic lifecycle and state-transition primitive;
- a domain-agnostic runtime environment descriptor;
- a clock abstraction for injectable time;
- a cooperative cancellation primitive;
- shared value types with value semantics and no product meaning;
- a typed-error abstraction.

Every public API in the package MUST be expressible without reference to any product, feature, provider, storage technology, or user interface.

### 2.2 What Must Never Belong in OmniaFoundation

The following MUST NEVER enter the package (ARC-002, ARC-008, ARC-009):

- business logic, feature logic, or product decisions;
- provider logic, provider models, or provider-specific code;
- storage logic, persistence, data models, or storage technology;
- networking;
- user interface, presentation state, or UI frameworks;
- security or cryptographic implementations (credential handling, encryption engines);
- a dependency-injection framework or container (ARC-006 explicitly defines composition without a framework);
- the Configuration module's model — configuration levels, defaults ownership, and persistence are realized in OmniaDomain and OmniaInfrastructure (ARC-007), never here;
- code with no architectural home (ARC-002).

A primitive that acquires product meaning is a boundary violation and is re-homed to the layer that owns that meaning.

## 3. Public API Inventory

The initial public API is organized into the categories below. Each category states its purpose, its intended consumers, its stability expectations, and its ownership. The categories are the contract; the concrete declarations are defined during implementation and MUST conform to this inventory.

### 3.1 Identifiers

- **Purpose**: a stable, value-typed representation of identity with no product meaning. Domain aggregates — workspaces, conversations, providers, and credential references — require stable identity that persists over time (ARC-003 Entity, ARC-007).
- **Intended consumers**: OmniaDomain (entities and aggregates), OmniaApplication (references in use cases), OmniaInfrastructure (persistence mapping), OmniaPresentation (state references). The identifier is consumed by value and never by lookup of its construction.
- **Stability expectations**: stable. Identity is foundational and pervasive; a breaking change to the identifier API is a replacement, never a revision (ARC-008).
- **Ownership**: OmniaFoundation.

### 3.2 Lifecycle

- **Purpose**: a generic state-transition primitive that represents lifecycle states and transitions without encoding any specific lifecycle. The architecture defines explicit lifecycles — provider lifecycle states (ARC-004), conversation and streaming state, and the session and lifetime model (ARC-006, ARC-007) — all of which require a domain-agnostic mechanism to represent and constrain transitions.
- **Intended consumers**: OmniaDomain (provider lifecycle model, conversation state), OmniaApplication (session and workflow orchestration), OmniaInfrastructure (provider and connection state).
- **Stability expectations**: stable. The primitive is generic; provider-specific states are defined by the consumers of the model, never by this package.
- **Ownership**: OmniaFoundation.

### 3.3 Environment

- **Purpose**: a domain-agnostic descriptor of the runtime environment — the Apple platform and its version — with no product meaning. The product targets iOS, iPadOS, and macOS (PRODUCT_CHARTER), and platform-aware behavior must be decided without coupling the Domain or Application layers to a specific platform.
- **Intended consumers**: OmniaInfrastructure (platform services), OmniaApp (startup and capability checks), and any consumer that needs native-context awareness without UI coupling.
- **Stability expectations**: stable. The descriptor is additive; new platform facts are added without changing existing facts.
- **Ownership**: OmniaFoundation.

### 3.4 Configuration

- **Purpose**: a configuration primitive that provides typed value access with defaults, without persistence and without product decisions. Configuration is consumed from the interface down to infrastructure and is cross-cutting (ARC-001); a shared primitive is its foundation. User ownership and default-driven behavior are product invariants (PRODUCT_CHARTER, PRODUCT_PRINCIPLES).
- **Intended consumers**: every layer allowed to depend on Foundation. Configuration values are delivered to consumers by composition (ARC-006), never acquired.
- **Stability expectations**: stable. The primitive holds values and defaults; it defines no levels, no persistence, and no product meaning.
- **Ownership**: OmniaFoundation.

### 3.5 Logging (protocols only)

- **Purpose**: the logging interface — the contract for emitting log messages, encoding the invariant that secrets, tokens, and conversation content are never logged (ARC-001). The package exposes protocols only; concrete logger implementations live in the layers that own the platform (OmniaInfrastructure) and are delivered by composition (ARC-006).
- **Intended consumers**: every layer. No consumer constructs a logger; every consumer receives one.
- **Stability expectations**: stable. The interface is a contract held by the whole system; changes are replacements, never silent revisions (ARC-008).
- **Ownership**: OmniaFoundation.

### 3.6 Clock Abstractions

- **Purpose**: an abstraction over time that allows time to be injected and isolated. Deterministic behavior requires that time and external state be injected or isolated (ARC-001); a clock abstraction is the mechanism.
- **Intended consumers**: OmniaDomain (policies, aggregates, time-dependent rules), OmniaApplication (use cases, retry and limit behavior), OmniaInfrastructure (timestamps and storage records).
- **Stability expectations**: stable. The abstraction is minimal and domain-agnostic.
- **Ownership**: OmniaFoundation.

### 3.7 Cancellation

- **Purpose**: a minimal cooperative cancellation primitive that allows long-running, streaming, provider-agnostic flows to be interrupted without coupling consumers to a specific provider or async infrastructure. Interruption and partial-response handling are architectural requirements of the Conversation workflow (ARC-001, ARC-007). The primitive complements — and never reimplements — the cancellation facilities of the Swift Standard Library.
- **Intended consumers**: OmniaDomain (streaming state), OmniaApplication (orchestration and transaction boundaries), OmniaInfrastructure (provider adapters and long-running operations).
- **Stability expectations**: stable. The primitive is minimal and general; it defines no streaming or provider behavior.
- **Ownership**: OmniaFoundation.

### 3.8 Shared Value Types

- **Purpose**: domain-agnostic value types with value semantics and no product meaning (ARC-003 Value Object, ARC-001 Immutable Domain Models). The initial justified instance is a version value type, required by the architecture's versioning commitments — stored data is versioned (ARC-005) and packages are versioned (ARC-008). Additional shared value types are added only when justified by the architecture (see Section 6).
- **Intended consumers**: OmniaDomain (aggregates and policies), OmniaInfrastructure (migration and versioned records), OmniaApp (lifecycle), and tooling.
- **Stability expectations**: stable. Value types are immutable once created; changes produce new values (ARC-001).
- **Ownership**: OmniaFoundation.

### 3.9 Error Abstractions

- **Purpose**: the typed-error abstraction that allows layers to declare explicit, typed failures without product meaning. Errors are explicit, typed, and never silently swallowed (ARC-001, ARC-003, SWIFT.md), and they cross every layer boundary. The abstraction is the shared foundation for that invariant; no error type with product meaning is defined by this package.
- **Intended consumers**: every layer. Errors are part of every boundary.
- **Stability expectations**: stable. The abstraction is the base contract; specific typed errors are owned by the layers that define their meaning.
- **Ownership**: OmniaFoundation.

### 3.10 Excluded from the Initial Contract

The following are evaluated and intentionally NOT part of the initial public API of OmniaFoundation:

- networking, URL and transport abstractions — owned by OmniaInfrastructure;
- persistence and storage abstractions — owned by OmniaDomain and OmniaInfrastructure;
- provider abstractions — owned by OmniaDomain and OmniaInfrastructure;
- security and credential abstractions — owned by OmniaDomain and OmniaInfrastructure;
- user interface concerns — owned by OmniaPresentation;
- dependency-injection infrastructure — defined by ARC-006, owned by OmniaApp at composition.

A category excluded here is introduced only through the evolution rules of Section 6, never by convenience (ARC-008).

## 4. Dependency Rules

OmniaFoundation sits at the bottom of the dependency graph (ARC-002, ADR-0002). Its dependency rules are therefore absolute:

- OmniaFoundation MUST NOT depend on any Omnia package. It declares no Omnia package dependency (ARC-009).
- OmniaFoundation MAY depend on the Swift Standard Library.
- OmniaFoundation MAY depend on Apple's Foundation framework only when justified: when the Swift Standard Library cannot express the primitive, and when the dependency introduces no product meaning and no coupling above the Foundation position.
- OmniaFoundation MUST NOT depend on third-party packages. Native Apple APIs are preferred over third-party libraries (SWIFT.md, PRODUCT_CHARTER).
- Every dependency MUST be declared in the package manifest; hidden dependencies are forbidden (ARC-008).
- OmniaFoundation MUST remain free of dependencies that any consumer would have to adopt. A dependency that leaks product, provider, storage, or UI meaning to consumers is a violation.

## 5. API Design Principles

Every public API in OmniaFoundation MUST satisfy the following principles. A proposed API that fails any principle is not added.

- **Small surface area.** The public API is minimal and intentional (ARC-008). Everything that does not need to be public remains internal; the public surface is never expanded to accommodate a single consumer's convenience.
- **Stable contracts.** The public API is the contract. It changes only through the replacement process, never as a silent revision (ARC-008).
- **Explicit ownership.** Every public API has exactly one owner. Shared ownership is a violation (ARC-007, ARC-008).
- **No business logic.** The package contains no business, feature, or product logic (ARC-002, ARC-009).
- **No provider logic.** The package contains no provider logic and no provider-specific code (ARC-002, ARC-004).
- **No storage logic.** The package contains no storage logic, persistence, or data model (ARC-002, ARC-005).
- **No UI concerns.** The package contains no user interface, presentation state, or UI framework (ARC-002).
- **Value semantics where practical.** Primitives are immutable value types; changes produce new values (ARC-001, SWIFT.md).
- **Typed, explicit errors.** Failures are represented by typed errors and are never silently swallowed (ARC-001, SWIFT.md).
- **Deterministic behavior.** Time, randomness, and external state are injected or isolated (ARC-001).
- **Precise naming.** Naming follows the architectural naming guidelines (ARC-003): the suffix of a name states the nature of the element; ambiguous or placeholder terminology is forbidden.

## 6. Evolution Rules

### 6.1 When New APIs May Be Added

A public API is added to OmniaFoundation only when:

- a primitive needed by the architecture cannot be expressed by an existing primitive;
- the addition is justified by an existing architectural requirement recorded in the architecture or product documents — never by speculation about future features;
- the addition satisfies every design principle of Section 5 and every responsibility boundary of Section 2;
- the addition is documented before it is used (PRODUCT_PRINCIPLES — Documentation First).

An API with no justified consumer is not added. A new primitive that acquires product meaning is re-homed to the layer that owns that meaning.

### 6.2 When APIs May Be Removed

A public API is removed only through the defined deprecation lifecycle (ARC-008):

1. **Announce** — the API is marked deprecated; no new consumers are added.
2. **Migrate** — existing consumers move to the replacement.
3. **Remove** — the API is removed when no consumer remains.

A significant removal is recorded in the package's version history and, when architectural, as an ADR (ARC-007).

### 6.3 Compatibility Expectations

- The public API follows Semantic Versioning (ARC-008, DOCUMENTATION.md).
- A revision MUST preserve the contract; a breaking change is a replacement, never a revision (ARC-008).
- Additions MUST be backward-compatible: new APIs are additive and MUST NOT alter the behavior of existing APIs.
- The dependency graph MUST remain acyclic, and OmniaFoundation MUST remain at the bottom of it (ARC-002, ADR-0002).
- Every change to this contract updates this document in the same change (PRODUCT_PRINCIPLES — Documentation First).

## 7. Initial Implementation Plan

Implementation proceeds in ordered phases. Each phase:

- introduces only APIs justified by the current architecture;
- keeps the package building and its tests green at every step;
- completes with the contract documented and the API covered by tests before any cross-package consumer is added.

### Phase 1 — Core Primitives

Order: Identifiers, Environment, Lifecycle.

Justification: identity is foundational — domain aggregates cannot exist without a stable identifier representation; the runtime environment descriptor and the generic lifecycle primitive are prerequisites for platform-aware and stateful behavior. These are the most widely depended-upon primitives and are stabilized first.

### Phase 2 — Runtime Interfaces

Order: Logging protocol, Clock protocol, Cancellation.

Justification: these are cross-cutting concerns required before any feature work. The logging interface enforces the invariant that secrets never enter logs (ARC-001); the clock abstraction enables deterministic behavior (ARC-001); the cancellation primitive enables interruption of streaming flows (ARC-001, ARC-007). All are interfaces — protocols and minimal primitives — and are stabilized before the layers that consume them are implemented.

### Phase 3 — Value and Error Foundations

Order: Shared value types (initial justified instance: version), Error abstraction.

Justification: versioned data (ARC-005) and typed, explicit errors (ARC-001, ARC-003) are standing architectural requirements that every layer depends on. These foundations are added once the runtime interfaces are stable.

### Phase 4 — Configuration Primitives

Order: Configuration primitive.

Justification: configuration is consumed from the interface down to infrastructure (ARC-001). The primitive is added last among the initial categories because it is consumed by the Configuration module, which is realized in OmniaDomain and OmniaInfrastructure (ARC-007); the primitive exists to serve that realization and is defined immediately before the Configuration module is implemented.

No API beyond the categories of Section 3 enters the package in these phases. Each phase ends in a state that is a valid, documented, tested increment of the public contract.
