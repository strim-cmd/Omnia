---
title: Cancellation API
document_id: DES-008
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
  - Documentation/Design/API/LOGGER_API.md
  - Documentation/Design/API/ENVIRONMENT_API.md
  - Documentation/Design/API/LIFECYCLE_API.md
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - .ai/standards/SWIFT.md
  - .ai/standards/TESTING.md
supersedes: []
tags:
  - design
  - foundation
  - cancellation
  - concurrency
  - api-specification
  - specification
  - engineering
---

# Cancellation API

> This document defines the canonical cooperative cancellation abstraction used across Omnia: its purpose, its API contract, its ownership, its design rules, and its usage guidelines. It intentionally avoids implementation.

## 1. Purpose

Omnia defines its own cancellation abstraction instead of letting direct reads of standard-library task cancellation and scattered interruption checks appear throughout the codebase. Direct use of task cancellation couples every cancellable flow to one async runtime and one execution model, and it leaves provider adapters and Domain streaming state — which are not necessarily task-bound — with no shared, provider-agnostic mechanism for interruption.

A single canonical abstraction exists for five reasons:

- **It decouples interruption from async infrastructure.** Direct task cancellation ties cancellation to a specific runtime and execution model. The Cancellation primitive makes interruption a declared, shareable, provider-agnostic boundary that synchronous and asynchronous flows observe alike (ARC-006, ARC-008).
- **It keeps cancellation cooperative.** Interruption and partial-response handling are architectural requirements of the Conversation workflow (ARC-001, ARC-007). A cooperative signal lets a flow stop at its own safe points, preserve its partial response, and report that it was interrupted rather than that it failed. A hard interruption would discard partial work and erase the distinction between cancelled and failed.
- **It makes cancellation deterministic and testable.** A test must be able to request and observe cancellation exactly, without timing or external state. An injectable, shared signal satisfies that requirement (ARC-001, DES-001).
- **It keeps policy where it belongs.** The primitive provides the signal, nothing else. Timeouts, retries, backoff, and scoping remain consumer concerns expressed in terms of cancellation, never properties of the primitive.
- **It complements the standard library, never reimplements it.** The Swift Standard Library remains the cancellation facility for async tasks. This primitive is the shared, provider-agnostic boundary that async infrastructure MAY bridge to standard-library cancellation and that non-task contexts observe directly; it never replaces the standard library.

All cancellable behavior in Omnia — long-running, streaming, provider-agnostic flows — is expressed through the Cancellation primitive. Consumers receive the observation by composition and never acquire cancellation from global state (DES-001).

The abstraction is not a convenience; it is the enforcement of the interruption boundary the architecture requires.

## 2. Design Goals

The abstraction is designed to satisfy the following goals. Each goal is a normative requirement of the API and is verified by the tests in Section 7.

- **Cooperative interruption.** Cancellation signals the operation; it never hard-interrupts it. The operation stops at its own safe points and never wastes work past the point of request.
- **Provider-agnostic.** The abstraction references no provider, no transport, no streaming implementation, and no async runtime. Any flow can be interrupted through the same mechanism.
- **One-way signal.** A request is never revoked. Once cancellation is requested it is observed by every subsequent check.
- **Deterministic observation.** A test controls the request and the observation; behavior is reproducible with no timing, wall-clock, or ordering dependence (ARC-001, TESTING.md).
- **Safe sharing.** The signal is observable by any number of observers and safe to share across concurrency domains; reads are consistent and free of mutation (SWIFT.md).
- **Cancelled is distinct from failure.** A flow that stops because of cancellation is reported as interrupted, never as errored; callers distinguish the two outcomes (ARC-001, ARC-007).
- **Complementary to the standard library.** The primitive never reimplements the cancellation facilities of the Swift Standard Library; it bridges to them where a flow is task-bound.
- **Explicit ownership.** Every cancellation source has an owner. Operations receive the observation by composition; nothing acquires it (ARC-006, ARC-007).
- **Minimal public surface.** The contract exposes exactly the cancellation boundary and no more. Timeouts, retry, backoff, and scoping are consumer concerns (ARC-008).

## 3. Public API

The public API is conceptual. It specifies what the abstraction provides, not how it is provided.

| Element | Definition |
|---|---|
| Cancellation | The cooperative interruption boundary through which a long-running or streaming operation is stopped. It is the single way an in-flight flow learns that it should stop. |
| Cancellation Source | The owner's handle: the one place a cancellation request is made. A source is created for one operation and is never reused. |
| Cancellation Observation | The operation's handle: the one place an operation learns whether cancellation has been requested. An operation holds the observation for the operation's lifetime. |
| Cancellation signal | The observable, one-way fact that a request has been made. Once signalled it never reverts, and every observation afterwards reports cancelled. |
| Cancellation check | The safe point at which an operation observes the signal and decides to stop. Checks are the operation's own choice of when to notice the request. |
| Cancelled outcome | The distinct result of a flow that stopped because of cancellation. It is reported separately from any error and never masquerades as one. |

Normative statements:

- The API MUST expose exactly the elements above and no more.
- A request MUST be one-way: once made, it is never revoked, and every subsequent observation reports cancelled.
- Cancellation MUST be cooperative: the signal never hard-interrupts, never aborts, and never force-stops; the operation stops at its own safe points.
- The API MUST NOT reference any provider, transport, streaming implementation, or async runtime.
- The API MUST complement and MUST NOT reimplement the cancellation facilities of the Swift Standard Library.
- The signal MUST be observable by any number of observers and MUST be safe to share across concurrency domains.
- A cancelled flow MUST be distinguishable from a failed flow.
- The API MUST NOT provide timeouts, retries, backoff, deadlines, or scope policy.
- The signal MUST be delivered by composition; there is no global cancellation state and nothing is acquired by lookup.

## 4. Ownership

- **Who owns the abstraction.** OmniaFoundation owns the Cancellation contract. It is the shared interruption boundary of the whole system, with no product meaning (DES-001).
- **Who creates sources.** The code that starts a cancellable operation creates its source: Application orchestration at transaction boundaries, a provider adapter at the start of a long-running operation. A source is created by composition when the operation starts and is never reused (ARC-006).
- **Who injects observations.** The operation's owner hands the observation to the operation when it starts. Every operation that can be interrupted declares the observation and receives it; nothing acquires cancellation by lookup or from global state (ARC-006).
- **Who consumes them.** Every layer that runs long-running or streaming work: OmniaDomain (streaming state), OmniaApplication (orchestration and transaction boundaries), OmniaInfrastructure (provider adapters and long-running operations) (DES-001).
- **Lifetime.** A source lives for the operation it governs, from start until completion or cancellation. The observation is valid for the operation's lifetime and is not retained beyond it.

## 5. Usage Rules

- **Inject the observation, never acquire it.** Cancellable flows receive the observation by composition; nothing acquires cancellation from global state or by lookup (ARC-006).
- **Signal, never force.** An owner requests cancellation and lets the operation stop cooperatively. It never hard-interrupts or aborts the operation.
- **Observe at safe points.** A cancellable flow checks for cancellation between units of work and stops promptly; it never does work that the request has already rendered pointless.
- **Cancelled is not failure.** A flow that stops because of cancellation reports the cancelled outcome distinctly from an error. A cancelled flow is not a failed flow, and a failed flow is not silently reported as cancelled (ARC-001, ARC-007).
- **Never reuse a source.** A cancellation source is created for one operation and is never reused for a later one.
- **Never reimplement the standard library.** For task-bound flows, cancellation bridges to the standard library's facilities; the primitive is the shared boundary, not a second implementation of them.
- **Never assume in-flight work is interrupted.** A request takes effect at the operation's next safe point; a flow must not assume that work already in progress is discarded.

## 6. Architectural Constraints

- **No business logic.** The abstraction carries no business, feature, or product content (DES-001).
- **No provider logic.** It knows nothing about providers and never references provider concepts (DES-001).
- **No streaming or transport.** It defines no streaming behavior, no partial-response handling, and no transport.
- **No policy.** It provides no timeouts, retries, backoff, deadlines, or scope rules.
- **No hard interruption.** It never aborts threads, terminates processes, or force-stops work; interruption is always cooperative.
- **No global state.** It defines no global cancellation registry and nothing reached by lookup; cancellation is delivered by composition (ARC-006).
- **No reimplementation of the standard library.** The Swift Standard Library remains the cancellation facility for async tasks; this primitive complements it and never replaces it (DES-001).
- **No product meaning.** The abstraction lives in the Foundation position and carries no product content (DES-001).
- **No Omnia package dependency.** The abstraction sits at the bottom of the dependency graph and introduces no dependency on any Omnia package (ARC-002, ADR-0002).

## 7. Testing Requirements

The abstraction MUST be verified by behavioural tests. The required tests cover:

- **Initial state** — an observation reports not cancelled before any request.
- **Request observed** — a request makes the observation report cancelled.
- **One-way signal** — after a request, the observation remains cancelled; a request is never revoked.
- **Cooperative stop** — a flow that checks after a request stops at its safe point; a flow that never checks is not interrupted (no hard interruption).
- **Multiple observers** — any number of observers receive the same signal from one source.
- **Distinct outcomes** — a cancelled flow is reported distinctly from a failed flow; the two outcomes are never conflated.
- **Shared concurrency** — an observation shared across concurrency domains reads consistently, introduces no mutation, and is free of data races under Swift 6 (SWIFT.md).
- **Infrastructure independence** — synchronous consumers observe the signal directly; observation does not require a task, a runtime, or standard-library cancellation machinery.
- **Deterministic behavior** — tests request and observe cancellation explicitly; no test depends on timing, the wall clock, or the order of other tests (TESTING.md, ARC-001).

Every test MUST be deterministic and independent (TESTING.md, ARC-001).

## 8. Future Evolution

Cancellation sources are introduced without changing the public contract:

- **Manual Source** — cancellation requested explicitly by the flow's owner.
- **Task-Linked Source** — a source whose observation propagates to, or is propagated from, standard-library task cancellation, so a task-bound flow stops automatically. This bridges to the standard library and never reimplements it.
- **Scoped Source** — a parent source whose cancellation fans out to the child operations it governs, for orchestrated multi-step flows.

Derivation rules:

- Adding a source is additive: it realizes the existing contract and never changes the public API.
- A new source is introduced only when the architecture justifies it, and it is documented before use (PRODUCT_PRINCIPLES — Documentation First).
- Existing consumers keep their behavior when a new source is introduced.

The core contract remains the single shared interruption boundary; sources extend it by delivering the same cooperative signal, never by changing the contract.

## Related Documents

- `Documentation/Design/FOUNDATION_API.md` — the OmniaFoundation public API contract this document realizes.
- `Documentation/Design/API/IDENTIFIER_API.md` — the canonical Identifier abstraction, a sibling primitive this document's conventions follow.
- `Documentation/Design/API/CLOCK_API.md` — the canonical time abstraction, a sibling primitive this document's conventions follow.
- `Documentation/Design/API/LOGGER_API.md` — the canonical logging interface, a sibling primitive this document's conventions follow.
- `Documentation/Design/API/ENVIRONMENT_API.md` — the canonical environment descriptor, a sibling primitive this document's conventions follow.
- `Documentation/Design/API/LIFECYCLE_API.md` — the canonical lifecycle primitive, a sibling primitive this document's conventions follow.
- `Documentation/Architecture/07_MODULE_STRUCTURE.md` — the modules whose streaming and long-running flows carry interruption.
- `Documentation/Architecture/08_PACKAGE_MODEL.md` — the package model, stability, and boundary rules.
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` — OmniaFoundation's responsibilities and dependencies.
- `.ai/standards/SWIFT.md` — concurrency and value-semantics rules.
- `.ai/standards/TESTING.md` — deterministic, independent tests.
