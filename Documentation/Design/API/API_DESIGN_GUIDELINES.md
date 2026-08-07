---
title: API Design Guidelines
document_id: DES-004
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
  - Documentation/Design/API/IDENTIFIER_API.md
  - Documentation/Design/API/CLOCK_API.md
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - Documentation/Development/DocumentationStandard.md
  - .ai/standards/SWIFT.md
  - .ai/standards/TESTING.md
supersedes: []
tags:
  - design
  - api-specification
  - standard
  - specification
  - engineering
---

# API Design Guidelines

> This document is the canonical engineering standard for every public API specification in Omnia. It defines what an API specification is, how it is structured, and the principles, compatibility rules, testing philosophy, and review criteria it must satisfy. It is not an architecture document and it is not an implementation guide.

## 1. Purpose

API specifications are the contracts consumers depend on. A public API is the complete and only surface through which a package is consumed (ARC-008); a specification records that surface before any implementation exists, so the contract is reviewable, stable, and deliberate rather than emergent (PRODUCT_PRINCIPLES — Documentation First).

API specifications exist for three reasons:

- **They define the contract before use.** The architecture requires that a public API is documented before it is used (DES-001 §6.1). The specification is the record of that decision and the reference every consumer and every implementation is measured against.
- **They define WHAT, never HOW.** A specification states the contract the implementation must honor and never describes the implementation, so the implementation can be replaced without changing the contract (ARC-008). An API is a boundary; the specification is the written boundary.
- **They centralize the decisions.** A specification records why an abstraction exists, who owns it, who may use it, and how it may evolve, in one place, so the decisions are not scattered and duplicated across callers.

### Relationship to Architecture Documents

The architecture documents (ARC series) define what exists, who owns it, and the boundaries and dependency edges it must respect. An API specification defines the contract surface within those boundaries. The relationship is one of constraint, not of invention:

- A specification MUST conform to the architecture: ownership is inherited from the module that owns the abstraction (ARC-007), the dependency position is inherited from the package model (ARC-008, ARC-009), and the public API inventory is inherited from the parent contract (DES-001 §3).
- A specification MUST NOT introduce a category, responsibility, or dependency that the architecture does not contain. Where a specification and the architecture disagree, the specification is corrected; the architecture is never revised to accommodate a spec.
- A specification realizes an inventory category of the parent contract (DES-001 §3). It refines the category into a concrete conceptual contract; it never redefines the category.

### Relationship to Implementation

The specification is normative. Implementation MUST conform to it:

- A mismatch between the specification and the code is a defect in the code and is resolved by correcting the code, never by silently changing the specification.
- The specification intentionally avoids implementation so the implementing engineer maps concepts to real declarations. The spec is the contract; the declaration is the realization.
- The specification changes only through the compatibility rules of Section 4. A silent revision of a published contract is a violation (ARC-008).

### Scope and Non-Goals

This standard governs every public API specification in `Documentation/Design/API/` and every specification added to that directory in the future. It does not define module structure, package topology, coding conventions, or test tooling; those are governed by the architecture and standards documents it references.

## 2. Required Document Structure

Every public API specification MUST contain the following sections, in order, with these names and this mandatory content:

| Section | Mandatory content |
|---|---|
| Purpose | Why the abstraction exists; why direct alternatives are unacceptable; the boundary it enforces; scope and non-goals. |
| Design Goals | The normative goals the API is designed to satisfy. Each goal is a requirement and is verified by the tests in Testing Requirements. |
| Public API | The conceptual contract: the elements the API provides and the normative statements that bound it. It defines what, never how. |
| Ownership | Who owns the abstraction; who creates it; who injects it; who consumes it; its lifetime. |
| Usage Rules | The rules consumers follow: prohibitions and mandatory practices. |
| Architectural Constraints | What the abstraction MUST NOT contain or do; its position in the dependency graph. |
| Testing Requirements | The behavioural tests that verify the Design Goals. Every test is deterministic and independent. |
| Future Evolution | How the abstraction extends additively without changing the core contract. |
| Related Documents | The architecture, parent-contract, and standards documents that govern this API. |

Rules:

- A specification MUST NOT omit, reorder, or rename a section.
- The Public API section MUST be conceptual. It MAY present a table of elements followed by normative statements.
- Normative statements use MUST, MUST NOT, MAY, and NEVER; they are the enforceable contract and they are never phrased aspirationally.
- The document MUST NOT contain Swift code, pseudocode, or implementation detail.
- The frontmatter MUST record document_id, version, status, owner, authors, reviewers, created, last_updated, related_documents, supersedes, and tags.
- A change to a public API updates its specification in the same change (DES-001 §6.3, PRODUCT_PRINCIPLES — Documentation First).

## 3. API Design Principles

Every public API in Omnia MUST satisfy the following principles. A proposed API that fails any principle is not designed for Omnia.

- **Minimal public surface.** The public API is the smallest intentional contract that satisfies its purpose. Everything that does not need to be public remains internal; the surface is never expanded for a single consumer's convenience (ARC-008).
- **Strong typing.** The abstraction gives concepts a type so the build system prevents mixing (ARC-002). Raw values are not exposed across package boundaries; identities, configuration values, and errors are typed, not aliases of raw values.
- **Explicit ownership.** Every public API has exactly one owner (ARC-007, ARC-008). Shared ownership is a violation. Ownership is recorded in the specification.
- **Immutable by default.** Public values are immutable once created; changes produce new values (ARC-001, SWIFT.md).
- **Value semantics where appropriate.** Primitives and state models are value types; reference types are used only where identity or shared state is required (SWIFT.md).
- **Protocol-oriented design.** Dependencies are expressed against protocols; concrete implementations are bound at the Composition Root (ARC-006).
- **Dependency inversion.** Consumers depend on contracts, never on concrete implementations and never on the construction of dependencies (ARC-006).
- **No hidden global state.** No global state and no acquired dependencies. Consumers receive what they need by composition; nothing is reached by lookup (ARC-006).
- **No convenience APIs without justification.** A public API is added only when an existing architectural requirement needs it and no existing primitive can express it (DES-001 §6.1). An API with no justified consumer is not added.
- **No speculative features.** Nothing is added for imagined future features. Extensibility is designed as additive derivation in Future Evolution, never as speculative surface.
- **Deterministic behavior.** Time, randomness, and external state are injected or isolated (DES-001 §5, ARC-001).
- **No business, provider, storage, or UI logic.** The Foundation position carries no product meaning; the specification states the boundaries it will not cross (DES-001 §2, §5).
- **Typed, explicit errors.** Failures are represented by typed errors and are never silently swallowed (ARC-001, SWIFT.md).
- **Precise naming.** Names state the nature of the element; ambiguous or placeholder terminology is forbidden (ARC-003).

## 4. Compatibility Rules

The public API is a contract held by the whole system. It changes only through the rules below; a silent revision of a published contract is a violation (ARC-008).

- **Source compatibility.** A revision MUST preserve the contract and MUST NOT break existing consumers. Additions are additive: they introduce new declarations and never alter the behavior of existing ones.
- **Binary compatibility.** Packages follow Semantic Versioning (ARC-008, DocumentationStandard). Binary compatibility is the forward commitment of the versioning scheme; it is preserved across revisions and broken only by a documented replacement.
- **Semantic Versioning.** A change that preserves the contract is a revision. A change that breaks the contract is a replacement and requires a major version change. The versioning scheme is defined by the package model (ARC-008).
- **Serialized-form stability.** A primitive that persists MUST specify a serialized form that is stable across versions and round-trips exactly; existing serialized data keeps its meaning when the API evolves (DES-002).
- **Deprecation process.** A public API is removed only through the defined lifecycle (ARC-008):
  1. **Announce** — the API is marked deprecated; no new consumers are added.
  2. **Migrate** — existing consumers move to the replacement.
  3. **Remove** — the API is removed when no consumer remains.
  A significant removal is recorded in the version history and, when architectural, as an ADR (ARC-007).
- **Documentation First.** Every change to a public API updates its specification in the same change, before or with the implementation (PRODUCT_PRINCIPLES, DES-001 §6.3).

## 5. Testing Philosophy

The verification of a public API is specified in its Testing Requirements section and follows these rules.

- **Behavioural tests.** Tests verify the behavior the specification defines — the Design Goals — not the mechanism that produces it. The specification states the goals; the tests prove the goals.
- **Black-box testing.** Tests exercise only the public API. They never depend on internals, and they compose dependencies with test doubles (ARC-008). A test that reaches into internals verifies nothing about the contract.
- **No implementation-driven tests.** A test is never written to mirror a declaration's structure or an implementation decision. Tests that pass only because they mirror internals fail to protect the contract and break when internals change.
- **Deterministic testing.** Every test is deterministic and independent (TESTING.md, ARC-001). Time, randomness, and external state are injected or isolated (DES-001 §5). No test depends on the wall clock, the network, connectivity, or the order of other tests.
- **Goal coverage.** The Testing Requirements section MUST verify every Design Goal. A design goal without a test is an aspiration, not a requirement.
- **Independence.** Tests are independently runnable and repeatable; shared mutable state and order dependence are violations.

## 6. Review Checklist

The following is the Definition of Done for every public API specification. A specification that does not satisfy every check is not approved.

- [ ] **Minimal public API.** The Public API section exposes exactly the elements the purpose requires and no more; normative MUST NOT statements bound the surface.
- [ ] **Tests specified.** The Testing Requirements section verifies every Design Goal with deterministic, independent, black-box behavioural tests.
- [ ] **Ownership defined.** Exactly one owner is recorded, together with creation, injection, consumption, and lifetime.
- [ ] **Architectural constraints defined.** The MUST NOT inventory is complete and consistent with the parent contract (DES-001) and the package model (ARC-008).
- [ ] **Usage rules defined.** Consumer prohibitions and mandatory practices are stated.
- [ ] **Future evolution documented.** Additive derivation is described without changing the core contract.
- [ ] **No implementation leakage.** The document contains no Swift code, no pseudocode, and no implementation detail; it defines what, never how.
- [ ] **Normative language.** The contract is expressed with MUST, MUST NOT, MAY, and NEVER; the enforceable sections contain no ambiguous or aspirational phrasing.
- [ ] **Compatibility respected.** The API changes only per Section 4, and the specification is updated in the same change.
- [ ] **Related documents listed.** The architecture, parent-contract, and standards references are recorded.

## Related Documents

- `Documentation/Design/FOUNDATION_API.md` — the parent contract this standard governs.
- `Documentation/Design/API/IDENTIFIER_API.md` — a realized specification that follows this standard.
- `Documentation/Design/API/CLOCK_API.md` — a realized specification that follows this standard.
- `Documentation/Architecture/07_MODULE_STRUCTURE.md` — module ownership and boundaries.
- `Documentation/Architecture/08_PACKAGE_MODEL.md` — package boundaries, stability, and lifecycle.
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` — package topology and responsibilities.
- `Documentation/Development/DocumentationStandard.md` — the general documentation standard this standard specializes.
- `.ai/standards/SWIFT.md` — the coding standard that governs implementation.
- `.ai/standards/TESTING.md` — the testing standard that governs implementation.
