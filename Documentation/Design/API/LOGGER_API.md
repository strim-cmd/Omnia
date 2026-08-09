---
title: Logger API
document_id: DES-005
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
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - project Swift standards
  - project testing standards
supersedes: []
tags:
  - design
  - foundation
  - logging
  - api-specification
  - specification
  - engineering
---

# Logger API

> This document defines the canonical logging abstraction used across Omnia: its purpose, its API contract, its ownership, its design rules, and its usage guidelines. It intentionally avoids implementation.

## 1. Purpose

Omnia defines its own logging abstraction instead of exposing platform-specific logging APIs throughout the codebase. Direct use of platform logging, printing, and console output scatters the decision of what may be logged across every caller, and every scattered decision is a dependency the architecture does not control.

A single canonical abstraction exists for five reasons:

- **It makes the logging boundary declarable.** Platform logging APIs differ across platforms and evolve independently. A shared contract keeps every consumer stable when the platform changes (ARC-008), and it keeps Omnia platform-independent at every layer above the platform owner.
- **It makes the ARC-001 invariant enforceable.** The invariant that secrets, tokens, and conversation content are never logged cannot be enforced when every caller reaches for a platform API. The Logger encodes the invariant in the interface, so the decision is made once, in the contract, and cannot be re-decided per caller.
- **It makes logging testable.** A consumer that receives a logger by composition can be verified with a recording logger in a deterministic test. Direct platform output cannot be intercepted or asserted on.
- **It keeps implementation out of Foundation.** The abstraction is protocols only (DES-001 §3.5). It defines emission and nothing else: destinations, formatting, persistence, filtering, and transport are deliberately excluded from the contract and belong to future implementations in the layer that owns the platform.
- **It keeps diagnostics out of product behavior.** Log events are records, not mechanisms. No consumer branches product behavior on logging, and metadata is never a source of behavior.

The abstraction is not a convenience; it is the enforcement of the logging boundary the architecture requires.

## 2. Design Goals

The abstraction is designed to satisfy the following goals. Each goal is a normative requirement of the API and is verified by the tests in Section 7.

- **Provider-independent.** The interface carries no provider coupling; consumers never reference a platform logger or any concrete logging backend (DES-001 §3.5).
- **Testable.** Loggers are delivered by composition; tests inject a recording logger and assert on exactly what was recorded.
- **Deterministic.** Emission is deterministic and independent. Timestamps come from the Clock abstraction, never from direct system-time reads (DES-003, DES-001 §5).
- **Structured logging.** Events carry structure — level, message, metadata, timestamp, and context — and the contract preserves that structure rather than flattening it to text.
- **Strong typing.** Levels and contexts are typed; sensitive content is structurally excluded from the log path (ARC-002).
- **Redaction.** The ARC-001 invariant — secrets, tokens, and conversation content are never logged — is encoded by the API, not left to convention.
- **Minimal API.** The contract is a single interface with a fixed element set. It provides no destinations, no formatting, no persistence, no filtering, and no transport.
- **Platform-independent.** The abstraction carries no platform coupling; the platform is reached only through an implementation in the layer that owns it.

## 3. Public API

The public API is conceptual. It specifies what the abstraction provides, not how it is provided.

| Element | Definition |
|---|---|
| Logger | A protocol that records diagnostic events. It is the only path by which content enters a log. Consumers receive a logger by composition and never construct or acquire one. |
| Log event | A single diagnostic record: a level, a message, optional metadata, a timestamp obtained through the Clock, and a context. An event carries no identity and no product meaning beyond the event it describes. |
| Log level | An ordered, deterministic classification of an event's severity. Levels compare consistently with equality; the set is fixed and domain-agnostic. |
| Message | The human-readable text of the event. It never carries sensitive content. |
| Metadata | Optional structured attributes attached to an event for diagnostics. Metadata is preserved by the interface, is never a source of behavior, and never carries sensitive content. |
| Timestamp | The time at which the event occurred, obtained through the Clock abstraction. An event never reads system time directly (DES-003). |
| Context | The name of the emitting source, declared by the module that owns it. Contexts group events for diagnostics; the abstraction defines the mechanism, the owning module defines its own contexts, and the abstraction carries no product meaning. |
| Sensitive declaration | A value declared by its owner as not loggable. The interface provides no path by which a sensitive value becomes log content, and a sensitive value is never emitted in any form. |

Normative statements:

- The API MUST expose exactly the elements above and no more.
- The API MUST NOT provide destinations, formatting, persistence, filtering, or transport; those are implementation concerns, not contract elements.
- The Logger is the only path by which content enters a log; the API provides no other output channel.
- Sensitive values — secrets, tokens, and conversation content — are NEVER emitted, in any form, by any implementation (ARC-001). A sensitive declaration is never log content.
- Log levels order deterministically and compare consistently with equality.
- An event's timestamp is the current time reported by the Clock; the API never reads system time directly.
- An event is delivered to the logger as provided: level, message, non-sensitive metadata, timestamp, and context are preserved. Whether a given level is recorded is the implementation's concern, never the consumer's.
- Metadata is never a source of behavior.

## 4. Ownership

- **Who owns the abstraction.** OmniaFoundation owns the logging interface — protocols only, never implementations of a platform logger (DES-001 §3.5, ARC-007).
- **Who creates loggers.** Only composition creates loggers. The Composition Root binds the production logger once, for the application lifetime; tests create their own loggers. No consumer creates a logger (ARC-006).
- **Who injects them.** Loggers are delivered by composition. Every consumer that records diagnostics declares a logger and receives it; nothing acquires a logger by lookup or from global state (ARC-006).
- **Who consumes them.** Every layer. Any module that records diagnostics receives a logger. Concrete logger implementations live in the layer that owns the platform — OmniaInfrastructure (DES-001 §3.5).
- **Who owns log records.** The emitting module owns the content of its own events. The logger implementation owns the records it receives and their lifecycle. The interface defines emission, not storage; log records are not a contract of the abstraction (ARC-005).
- **Lifetime.** A logger is long-lived and outlives its consumers. It is owned by the composition that creates it; a consumer never owns the logger it receives (ARC-006).

## 5. Usage Rules

- **Never use platform logging APIs directly.** Platform loggers, printing, and console output appear only inside Logger implementations — never in consumer code.
- **Never use a global logger.** No global logger, no hidden singleton, no static access. Loggers are injected (ARC-006).
- **Always inject.** A consumer that needs logging declares a logger and receives it; time and logging are never acquired implicitly.
- **Never log secrets, tokens, or conversation content.** Sensitive values are never converted to text for logging; they are declared sensitive and never enter the log path (ARC-001).
- **Never branch behavior on logging.** An event is a record, not a mechanism; product behavior never depends on whether or how a message is logged.
- **Timestamp through the Clock.** Events are timestamped by the Clock abstraction; consumers never read system time to annotate a log (DES-003).
- **Use your own context.** Contexts are declared by the module that owns them; a consumer uses the context it owns, never a foreign one.

## 6. Architectural Constraints

- **No persistence.** The abstraction performs no storage; log records are not persisted by the interface (ARC-005).
- **No transport.** The abstraction defines no network or remote delivery.
- **No formatting.** The abstraction performs no formatting for presentation; the contract preserves structure, not presentation.
- **No rotation.** The abstraction defines no log rotation or record lifecycle policy.
- **No business logic.** The abstraction carries no business, feature, or product content (DES-001).
- **No analytics.** The Logger is not an analytics channel; events carry no product telemetry meaning.
- **No provider logic.** The abstraction knows nothing about providers and never references provider concepts.
- **No UI concerns.** The abstraction carries no user interface or presentation state.
- **No product meaning.** The abstraction lives in the Foundation position and carries no product content (DES-001).
- **No Omnia package dependency.** The abstraction sits at the bottom of the dependency graph and introduces no dependency on any Omnia package (ARC-002, ADR-0002).
- **Platform dependency only where justified.** The platform MAY be relied on where recording diagnostic events requires it, and the dependency MUST NOT leak to consumers (DES-001).
- **The Logger is the only logging path.** The API provides no other channel by which content enters a log.

## 7. Testing Requirements

The abstraction MUST be verified by behavioural tests. The required tests cover:

- **Level propagation** — an event's level is delivered to the logger unchanged; levels order and compare consistently with equality.
- **Metadata propagation** — metadata attached to an event is delivered and preserved by a recording logger.
- **Deterministic timestamps** — timestamps come from the injected Clock; with a controlled clock the timestamps are exact and reproducible, and no event depends on the wall clock (DES-003).
- **Injection** — a consumer receives a logger by composition and logs through it; a recording logger replaces the production logger without changing the consumer (ARC-006).
- **Concurrent safety** — a logger shared across concurrency domains records events without loss, duplication, or corruption, and is free of data races under Swift 6 (SWIFT.md).
- **Structured event preservation** — a recording logger observes the event's level, message, metadata, timestamp, and context intact; structure is preserved, not flattened.
- **Redaction** — no event carries secrets, tokens, or conversation content; a sensitive declaration never reaches recorded output in any form (ARC-001).

Every test MUST be deterministic and independent (TESTING.md, ARC-001).

## 8. Future Evolution

Logger implementations are introduced without changing the public API:

- **Apple Logger** — a production implementation backed by the platform's unified logging, provided by the layer that owns the platform.
- **swift-log bridge** — an implementation that adapts an external logging backend; the bridge lives outside OmniaFoundation and the public contract never depends on it.
- **Test Logger** — a recording implementation for deterministic tests.
- **Memory Logger** — a bounded in-memory implementation for diagnostics within a process lifetime.

Derivation rules:

- Adding an implementation is additive: it realizes the existing contract and never changes the public API.
- A new implementation is introduced only when the architecture justifies it, and it is documented before use (PRODUCT_PRINCIPLES — Documentation First).
- No implementation MAY weaken the redaction invariant; the guarantee that secrets, tokens, and conversation content are never logged holds for every implementation.

The core contract remains the single shared boundary; implementations extend it by recording events, never by changing the contract.

## Related Documents

- `Documentation/Design/FOUNDATION_API.md` — the OmniaFoundation public API contract this document realizes.
- `Documentation/Design/API/API_DESIGN_GUIDELINES.md` — the standard this specification must satisfy.
- `Documentation/Design/API/IDENTIFIER_API.md` — the canonical Identifier abstraction, whose conventions this document follows.
- `Documentation/Design/API/CLOCK_API.md` — the Clock abstraction that supplies an event's timestamp.
- `Documentation/Architecture/07_MODULE_STRUCTURE.md` — the modules that consume logging and the Foundation module that owns the interface.
- `Documentation/Architecture/08_PACKAGE_MODEL.md` — the package model, stability, and boundary rules.
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` — OmniaFoundation's responsibilities and dependencies.
- `project Swift standards` — concurrency and value-semantics rules.
- `project testing standards` — deterministic, independent tests.
