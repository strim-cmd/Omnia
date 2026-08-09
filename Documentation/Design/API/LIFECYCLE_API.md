---
title: Lifecycle API
document_id: DES-007
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
  - Documentation/Design/API/ENVIRONMENT_API.md
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - project Swift standards
  - project testing standards
supersedes: []
tags:
  - design
  - foundation
  - lifecycle
  - api-specification
  - specification
  - engineering
---

# Lifecycle API

> This document defines the canonical lifecycle abstraction used across Omnia: its purpose, its API contract, its ownership, its design rules, and its usage guidelines. It intentionally avoids implementation.

## 1. Purpose

Omnia defines its own lifecycle abstraction because the architecture relies on explicit lifecycles that must be represented and constrained in one consistent way. Provider lifecycle states (ARC-004), conversation and streaming state, and the session and lifetime model (ARC-006, ARC-007) all require a domain-agnostic mechanism to represent and constrain transitions (DES-001 §3.2).

A single canonical abstraction exists for four reasons:

- **It centralizes the decision of what a lifecycle is.** Without a shared primitive, every module re-implements state transitions differently: states drift, illegal transitions are possible, and each implementation duplicates the same mechanism.
- **It makes transitions constraining.** A lifecycle is not a bag of states; it is a set of legal transitions. The primitive rejects a transition that is not declared legal, so a component cannot reach a state the architecture does not permit (ARC-004).
- **It makes transitions observable.** Long-lived components change state and other parts of the system must react. The primitive delivers an immutable event for every transition, so observation is uniform instead of scattered.
- **It stays generic.** The primitive encodes no specific lifecycle. Provider-specific states are defined by the consumers of the model, never by this package (DES-001 §3.2).

Lifecycle represents the observable state transitions of long-lived components. It does NOT represent dependency injection, application state, workflow logic, or business processes. Those concerns belong to composition, orchestration, and the modules that own them.

The abstraction is not a convenience; it is the enforcement of the state-transition boundary the architecture requires.

## 2. Design Goals

The abstraction is designed to satisfy the following goals. Each goal is a normative requirement of the API and is verified by the tests in Section 7.

- **Explicit states.** A lifecycle's states are named, distinct, finite, and declared before use. No implicit or ad-hoc state exists.
- **Observable transitions.** Every legal transition produces an event that observers receive. Observation is part of the contract, not an implementation option.
- **Immutable events.** A lifecycle event is an immutable value. It records a transition and never changes.
- **Deterministic behaviour.** Transitions are deterministic: the same transition applied to the same state always produces the same outcome, and no transition depends on the wall clock, external state, or the order of unrelated activity (ARC-001).
- **Testability.** A lifecycle is exercised with a declared set of states and legal transitions; tests verify ordering, rejection of illegal transitions, and observation without a platform.
- **Platform independence.** The primitive carries no platform coupling; it behaves identically wherever the product runs.

## 3. Public API

The public API is conceptual. It specifies what the abstraction provides, not how it is provided.

| Element | Definition |
|---|---|
| Lifecycle | A generic state-transition primitive that represents the observable state transitions of a long-lived component. It tracks the component's current state, accepts only legal transitions, and emits an immutable event for every transition. It encodes no specific lifecycle (DES-001 §3.2). |
| Lifecycle State | A named, distinct condition a component can be in. States are explicit, finite, and typed. The set of states is declared by the module that owns the specific lifecycle; the abstraction provides the mechanism, never the states. |
| Transition | A defined, legal movement from one state to another. A transition is the only way a state changes. A transition that is not declared legal is illegal and is rejected: the current state is unchanged and no event is emitted. Transitions are deterministic. |
| Lifecycle Event | An immutable record of a transition: the previous state and the new state. An event is a value; it reveals the transition and nothing else, and it carries no product meaning. |
| Observer | A consumer notified when a transition occurs. Observers receive events and never influence the lifecycle: observation is one-way, and an observer cannot drive, veto, or alter a transition. |

Normative statements:

- The API MUST expose exactly the elements above and no more.
- The lifecycle encodes no specific lifecycle; states and legal transitions are declared by the module that owns the component (DES-001 §3.2).
- A state changes only through a legal transition.
- An illegal transition is rejected: the current state is unchanged and no event is emitted.
- Events are immutable and identical to every observer.
- Transitions are deterministic: the same transition applied to the same state always produces the same outcome.
- The lifecycle MUST NOT execute business logic, own resources, or act as a composition mechanism.

## 4. Ownership

- **Who owns lifecycle.** Each specific lifecycle — its states and its legal transitions — is owned by the module that owns the component: provider lifecycle states by the Provider module, conversation and streaming state by the Conversation module, and the session and lifetime model by Application Core (DES-001 §3.2, ARC-007). OmniaFoundation owns the generic primitive.
- **Who emits transitions.** Only the owner of the lifecycle. The owning module drives its component through legal transitions; no other module drives a lifecycle it does not own.
- **Who observes them.** The lifecycle's observers — the modules that react to the component's state. Observation is one-way: observers receive events and never emit or alter transitions.

## 5. Usage Rules

- **Lifecycle describes state transitions.** It is not application state, workflow logic, or a business process.
- **Lifecycle never executes business logic.** The owning module decides what a transition means and acts outside the primitive; the primitive records state and delivers events.
- **Lifecycle never owns resources.** Resources belong to the component; the lifecycle only records state.
- **Only the owning module emits transitions.** A module never drives another module's lifecycle.
- **Never use lifecycle as a dependency container, service locator, or composition mechanism** (ARC-006).
- **Observers never influence transitions.** Observers receive events and react; they never veto, feed back into, or alter a transition.

## 6. Architectural Constraints

- **No scheduling.** The primitive never schedules, delays, or times transitions.
- **No dependency injection.** The primitive is never a container, a locator, or a composition mechanism (ARC-006).
- **No logging implementation.** The primitive is not a logger; diagnostics are consumed through the Logger interface (DES-005).
- **No networking.** The primitive performs no network access.
- **No persistence.** The primitive stores nothing; lifecycle state is not persisted by the abstraction (ARC-005).
- **No business logic.** The primitive carries no business, feature, or product content (DES-001).
- **No product meaning.** The abstraction lives in the Foundation position and carries no product content (DES-001).
- **No provider logic.** The primitive knows nothing about providers and never references provider concepts.
- **No Omnia package dependency.** The abstraction sits at the bottom of the dependency graph and introduces no dependency on any Omnia package (ARC-002, ADR-0002).
- **No platform dependency.** The primitive carries no platform coupling (DES-001).
- **No UI concerns.** The primitive carries no user interface or presentation state.

## 7. Testing Requirements

The abstraction MUST be verified by behavioural tests. Tests declare a concrete set of states and legal transitions to exercise the generic primitive; the primitive itself encodes no specific lifecycle. The required tests cover:

- **Transition ordering** — a sequence of legal transitions moves the lifecycle through the declared order; the final state is deterministic, and events are delivered in the order the transitions occurred.
- **Illegal transitions** — a transition that is not declared legal is rejected; the current state is unchanged and no event is emitted.
- **Observation** — every observer receives every emitted event, in order, with the correct previous and new states; events are immutable and identical to every observer.
- **Deterministic behaviour** — the same sequence of legal transitions always yields the same final state and the same event sequence, with no dependence on the wall clock, external state, or the order of other tests (ARC-001).

Every test MUST be deterministic and independent (TESTING.md, ARC-001).

## 8. Future Evolution

The Lifecycle API is the final Foundation API specification before the Foundation v1 freeze. Evolution is additive and never breaks the contract:

- **New specific lifecycles.** New lifecycles — more state sets and legal transitions — are declared by the modules that own their components, without changing the generic primitive (DES-001 §3.2). Provider, conversation, and session lifecycles extend the mechanism, never the contract.
- **Additive primitive capabilities.** A capability added to the primitive is additive: it introduces new behavior and never alters the semantics of existing states, transitions, or events.
- **Contract stability.** Existing lifecycles keep their meaning and their behavior when new lifecycles are introduced. After the v1 freeze, a change to the contract is a replacement, never a revision (ARC-008).
- **Documented before use.** A specific lifecycle is documented before it is used (PRODUCT_PRINCIPLES — Documentation First).

The core contract remains the single shared mechanism; specific lifecycles extend it by declaring states and legal transitions, never by modification.

## Related Documents

- `Documentation/Design/FOUNDATION_API.md` — the OmniaFoundation public API contract this document realizes.
- `Documentation/Design/API/API_DESIGN_GUIDELINES.md` — the standard this specification must satisfy.
- `Documentation/Design/API/IDENTIFIER_API.md` — the canonical Identifier abstraction, whose conventions this document follows.
- `Documentation/Design/API/CLOCK_API.md` — the Clock abstraction, a sibling primitive.
- `Documentation/Design/API/LOGGER_API.md` — the Logger interface, a sibling primitive.
- `Documentation/Design/API/ENVIRONMENT_API.md` — the Environment descriptor, a sibling primitive.
- `Documentation/Architecture/07_MODULE_STRUCTURE.md` — the modules whose components carry lifecycles.
- `Documentation/Architecture/08_PACKAGE_MODEL.md` — the package model, stability, and boundary rules.
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` — OmniaFoundation's responsibilities and dependencies.
- `project Swift standards` — concurrency and value-semantics rules.
- `project testing standards` — deterministic, independent tests.
