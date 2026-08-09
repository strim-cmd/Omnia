---
title: Clock API
document_id: DES-003
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
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - project Swift standards
  - project testing standards
supersedes: []
tags:
  - design
  - foundation
  - clock
  - time
  - api-specification
  - specification
  - engineering
---

# Clock API

> This document defines the canonical time abstraction used across Omnia: its purpose, its API contract, its ownership, its design rules, and its usage guidelines. It intentionally avoids implementation.

## 1. Purpose

Omnia defines its own time abstraction instead of letting direct reads of system time appear throughout the codebase. Direct use of `Date()`, continuous clocks, task sleeping, dispatch-queue timers, and platform equivalents scatters the decision of what time means across every caller, and every scattered decision is a dependency the architecture does not control.

A single canonical abstraction exists for five reasons:

- **It eliminates hidden dependencies on the platform.** Every direct time read is an implicit dependency on a specific time source and a specific representation. The Clock makes time a declared dependency that is injected, owned, and replaceable (ARC-006, ARC-008).
- **It makes deterministic testing possible.** A test cannot control system time. Any behavior that reads time directly is nondeterministic and order-dependent. Deterministic behavior requires that time be injected or isolated (DES-001, ARC-001); the Clock is the mechanism that satisfies that requirement.
- **It centralizes representation.** Every caller that reads a date or a duration currently decides how time is represented, compared, and measured, and those decisions drift apart. The Clock gives every layer one representation and one set of guarantees.
- **It removes scheduling from consumer code.** Task sleeping and dispatch-queue timers couple behavior to a specific scheduling mechanism and make that behavior untestable in isolation. Waiting is expressed through the Clock, so the scheduler is replaceable and the tests control it.
- **It keeps policy where it belongs.** The abstraction provides time, nothing else. Scheduling, retry, rate limiting, and deadlines remain consumer concerns expressed in terms of time, never properties of the time source.

All time-based behavior in Omnia is expressed through the Clock. Consumers — Domain policies, aggregates, and time-dependent rules; Application use cases and retry and limit behavior; Infrastructure timestamps and storage records — receive a clock and never read system time (DES-001).

The abstraction is not a convenience; it is the enforcement of the time boundary the architecture requires.

## 2. Design Goals

The abstraction is designed to satisfy the following goals. Each goal is a normative requirement of the API and is verified by the tests in Section 7.

- **Deterministic testing.** Time is injected, never read directly. Tests control the clock, advance it by known amounts, and reproduce behavior exactly (ARC-001, DES-001).
- **Replaceable implementation.** The contract is the boundary; the concrete clock is bound at the Composition Root. Any implementation honoring the contract can be substituted without changing a consumer (ARC-006).
- **Value-oriented API.** Time is expressed as values — instants and durations — that are immutable, comparable, and safe to share (ARC-001, SWIFT.md).
- **Async-first.** Waiting is an asynchronous operation expressed through the clock. It never blocks and is safe under Swift 6 concurrency.
- **Platform-independent.** The abstraction carries no platform coupling. The platform is reached only through a chosen implementation, never through consumer code.
- **Explicit ownership.** Every clock has an owner. Consumers receive clocks by composition; they never create or acquire them (ARC-006, ARC-007).
- **Minimal public surface.** The contract exposes exactly the time abstraction and no more. Policy, scheduling, retry, and persistence are consumer concerns (ARC-008).

## 3. Public API

The public API is conceptual. It specifies what the abstraction provides, not how it is provided.

| Element | Definition |
|---|---|
| Clock | A stable time abstraction that is the only way time enters consumer code: reading the current time, measuring elapsed time, and sleeping are all expressed through a clock. A clock reveals nothing about the platform that provides it. |
| Current time | The clock's answer to "what time is it now" for calendar purposes — timestamps, storage records, expiry, and calendar-based rules. It is wall-clock time and may be adjusted by the system. |
| Instant | An opaque, immutable point in time produced by a clock. Instants are compared and used as boundaries; they reveal nothing about how the clock produces them. |
| Duration | An immutable length of time, either between two instants or independent of any instant. Durations are compared and used to express waiting. |
| Measurement | Reading a clock twice and computing the duration between the reads. The elapsed duration between two reads is unaffected by adjustments to the current time: measurement serves intervals, retries, and backoff and remains reliable when wall-clock time changes. |
| Time comparison | Instants and durations order deterministically. Comparison is well-defined, consistent with equality, and identical for every clock. |
| Sleep | An asynchronous operation that waits until the clock's time has advanced by a given duration or reached a given instant. Sleep is expressed through the clock so tests control it. |

Normative statements:

- The API MUST expose exactly the elements above and no more.
- No element reveals the underlying time source or any product meaning.
- The API MUST NOT provide scheduling policy, retry policy, rate limits, deadlines, timers, or persistence.
- Current time and measurement are served by the same clock: a consumer that needs both receives one clock and one source of truth.
- An instant is meaningful only within the time domain of the clock that produced it; comparison across clocks is not defined.
- Sleep is asynchronous and never blocks.
- The elapsed duration between two reads MUST be unaffected by adjustments to the current time.

## 4. Ownership

- **Who owns the abstraction.** OmniaFoundation owns the Clock contract. It is the shared time boundary of the whole system, with no product meaning (DES-001).
- **Who creates clocks.** Only composition creates clocks. The Composition Root binds the production clock once, for the application lifetime; tests create their own clocks. No consumer creates a clock (ARC-006).
- **Who injects them.** Clocks are delivered by composition. Every consumer that needs time declares a clock and receives it; nothing acquires time by lookup or from global state (ARC-006).
- **Who consumes them.** Every layer that needs time: OmniaDomain (policies, aggregates, time-dependent rules), OmniaApplication (use cases, retry and limit behavior), OmniaInfrastructure (timestamps and storage records) (DES-001).
- **Lifetime.** A clock is long-lived and outlives its consumers. It is owned by the composition that creates it; a consumer never owns the clock it receives (ARC-006).

## 5. Usage Rules

- **Never call system time directly.** Direct reads of dates, continuous clocks, and platform time sources appear only inside Clock implementations.
- **Never call task-sleep directly.** Waiting is expressed through the Clock, never through a direct sleeping mechanism.
- **Never use timers for time-based behavior.** Dispatch-queue timers and platform equivalents are not a path for time; the Clock is the only time path.
- **Never hide a time source.** If behavior depends on time, it declares a Clock and receives it. Time is never a mock, a global, or an implicit dependency.
- **Inject Clock explicitly.** Consumers receive clocks; they never acquire them (ARC-006).
- **Express time as values.** Consumers compare instants and durations; they never inspect the underlying representation.
- **Restore timestamps, never reinterpret them.** Persisted time is reconstructed from storage records as instants and is never reformatted by consumers (ARC-005).
- **Never derive policy from the clock.** Scheduling, retry, rate limits, and deadlines are consumer concerns expressed in terms of the Clock's time.

## 6. Architectural Constraints

- **No business logic.** The abstraction carries no business, feature, or product content (DES-001).
- **No scheduling policy.** It defines no retry policy, no rate limits, no deadlines, and no backoff strategy.
- **No timers.** It provides no timer, no periodic callback, and no scheduler.
- **No persistence.** It stores nothing; timestamps are recorded by the consumers that own them (ARC-005).
- **Only the time abstraction.** The contract is the time boundary and nothing else.
- **No product meaning.** The abstraction lives in the Foundation position and carries no product content (DES-001).
- **No provider logic.** It knows nothing about providers and never references provider concepts.
- **No Omnia package dependency.** The abstraction sits at the bottom of the dependency graph and introduces no dependency on any Omnia package (ARC-002, ADR-0002).
- **Platform dependency only where justified.** The platform MAY be relied on where current calendar time or reliable elapsed measurement require it and where no product meaning is introduced; the dependency MUST NOT leak to consumers (DES-001).

## 7. Testing Requirements

The abstraction MUST be verified by behavioural tests. The required tests cover:

- **Deterministic time** — behavior is exercised through a controlled clock; no test depends on real system time, the wall clock, or the order of other tests (TESTING.md, ARC-001).
- **Manual advancement** — advancing the clock by a known duration changes current time and measurement by exactly that amount; setting the clock to a known instant produces that instant.
- **Sleep behaviour** — sleeping through the clock advances time deterministically without blocking; zero and negative durations are well-defined; sleep never bypasses the clock.
- **Elapsed measurement** — two reads measured through the clock yield the duration advanced between them.
- **Measurement stability** — adjusting the current time does not change the measured elapsed duration between two reads.
- **Time comparison** — instants and durations order deterministically and compare consistently with equality.
- **Concurrent use** — a clock shared across concurrency domains reads consistently, introduces no mutation, and is free of data races under Swift 6 (SWIFT.md).
- **Value semantics** — instants and durations are immutable values; copies behave identically.

Every test MUST be deterministic and independent (TESTING.md, ARC-001).

## 8. Future Evolution

Clock implementations are introduced without changing the public contract:

- **System Clock** — the production clock: real current time and real elapsed time from the platform.
- **Test Clock** — manual advancement for deterministic tests.
- **Frozen Clock** — a fixed current time that never advances; for snapshots and time-independent behavior.
- **Accelerated Clock** — advances faster than real time; for time-compressed scenarios and long-interval policies.

Derivation rules:

- Adding an implementation is additive: it realizes the existing contract and never changes the public API.
- A new implementation is introduced only when the architecture justifies it, and it is documented before use (PRODUCT_PRINCIPLES — Documentation First).
- Existing consumers keep their behavior when a new implementation is introduced.

The core contract remains the single shared boundary; implementations extend it by providing time, never by changing the contract.

## Related Documents

- `Documentation/Design/FOUNDATION_API.md` — the OmniaFoundation public API contract this document realizes.
- `Documentation/Design/API/IDENTIFIER_API.md` — the canonical Identifier abstraction, the sibling primitive this document's conventions follow.
- `Documentation/Architecture/07_MODULE_STRUCTURE.md` — the modules whose policies, aggregates, and records carry time.
- `Documentation/Architecture/08_PACKAGE_MODEL.md` — the package model, stability, and boundary rules.
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` — OmniaFoundation's responsibilities and dependencies.
- `project Swift standards` — concurrency and value-semantics rules.
- `project testing standards` — deterministic, independent tests.
