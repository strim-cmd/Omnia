---
title: Identifier API
document_id: DES-002
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
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - Documentation/Product/PRODUCT_PRINCIPLES.md
supersedes: []
tags:
  - design
  - foundation
  - identifier
  - api-specification
  - specification
  - engineering
---

# Identifier API

> This document defines the canonical identifier abstraction used across Omnia: its purpose, its API contract, its ownership, its design rules, and its usage guidelines. It intentionally avoids implementation.

## 1. Purpose

Omnia defines its own identifier abstraction instead of exposing raw String or UUID values throughout the system. Raw values are untyped and interchangeable: nothing prevents a conversation identifier from being used where a workspace identifier is expected, and nothing records that a value represents identity at all. Every use of a raw value would duplicate the decision of what identity means and how it is created, compared, and stored.

A single canonical abstraction:

- gives identity a type, so the build system prevents mixing identities of different concepts (ARC-002);
- centralizes creation, comparison, hashing, and serialization in one contract, so every layer shares the same guarantee;
- provides a stable, version-independent serialized form for on-device storage (ARC-005);
- enforces value semantics and immutability for all identity in the system (ARC-001);
- keeps identity free of product meaning in the Foundation position (DES-001) while giving consumers a single extension point for specialized identities;
- guarantees concurrency safety under Swift 6 (SWIFT.md).

The abstraction is not a convenience; it is the enforcement of the identity boundary the architecture requires.

## 2. Design Goals

The abstraction is designed to satisfy the following goals. Each goal is a normative requirement of the API and is verified by the tests in Section 7.

- **Strong typing.** Identity is bound to the concept it identifies; mixing identities of different concepts is prevented.
- **Value semantics.** Identifiers behave as values; equality is defined by content.
- **Immutability.** An identifier never changes after creation.
- **Safe comparison.** Equality is well-defined, deterministic, and consistent with hashing.
- **Stable serialization.** The serialized form is stable across application versions and round-trips exactly.
- **Hashable.** Identifiers work as dictionary keys and set members.
- **Sendable.** Identifiers are safe to share across concurrency domains.
- **Future extensibility.** Specialized identities derive from the canonical abstraction without changing it.

## 3. Public API

The public API is conceptual. It specifies what the abstraction provides, not how it is provided.

| Element | Definition |
|---|---|
| Identifier | A stable, opaque, value-typed token that identifies one domain concept. The identifier reveals nothing about the concept it identifies. |
| Identifier value | An immutable value whose equality is defined by its underlying unique value. A value either identifies a created aggregate or is a well-formed identity for which no aggregate exists yet; the abstraction does not answer existence. |
| Creation | The only way a new identifier enters the system is the canonical creation operation, which produces a new globally unique value. A stored identifier is reconstructed only by restoring its canonical serialized form. Consumers never construct identifiers by guessing or composition. |
| Equality | Two identifiers are equal if and only if they carry the same underlying unique value. Identifiers of different concepts are never equal to each other. |
| Hashing | Hashing is deterministic and consistent with equality: equal identifiers always hash equally. |
| Serialization | An identifier serializes to a single canonical string and restores from it exactly. The canonical form is stable across application versions, non-empty, ASCII, and safe for use as a storage key. Malformed input is rejected and never yields an identifier. |
| String representation policy | The canonical string is the only public serialized form and is used for storage, keys, and decoding. How an identifier appears in user-facing presentation is a presentation concern and is never a property of the abstraction. |
| Debug representation | A stable debug description exists for logs and diagnostics. It is distinct from the canonical string and may indicate the identity kind. It is never a source of behavior and is never used in presentation. |

Normative statements:

- The API MUST expose exactly the elements above and no more.
- No element reveals the underlying representation or any product meaning.
- The API MUST NOT provide mutation, ordering, metadata access, or existence checking.

## 4. Ownership

- **Who creates identifiers.** Identifiers are created only when a new aggregate is created, by the layer that owns the aggregate. The Presentation layer never creates identifiers.
- **Who owns them.** The aggregate owns its identity. OmniaFoundation owns the canonical identifier abstraction. The concept being identified, and its identity kind, is owned by the module that defines it (ARC-007).
- **Global uniqueness.** Generated identifiers are globally unique in practice — across kinds, devices, and time — and generation succeeds offline, without Omnia-owned infrastructure, providers, or network.
- **Whether providers may define identifiers.** No. Providers never define Omnia identifiers. Identity is local and owned by Omnia (ARC-005, PRODUCT_PRINCIPLES). An identifier a provider assigns to its own resources is provider data and never becomes part of the canonical abstraction.

## 5. Usage Rules

- **Never expose raw UUID values across package boundaries.** The canonical string is the only public serialized form.
- **Prefer typed identifiers over aliases.** Identity is expressed as a typed identifier of the concept, never as a type alias of a raw value.
- **Identifiers are immutable.** They are never mutated, and no API mutates them.
- **Identifiers contain no business logic.** An identifier is a value token; it never carries behavior with product meaning.
- **Consume identifiers by value.** Consumers receive and pass identifiers; they never acquire them by lookup or construct them by guessing.
- **Restore identifiers only from the canonical form.** Serialized identity is reconstructed through the canonical restoration operation, never by parsing a raw value.

## 6. Architectural Constraints

- **No dependency on Apple Foundation unless justified.** The abstraction MAY rely on the platform only where uniqueness or canonical form require it and where no product meaning is introduced; it MUST NOT leak that dependency to consumers.
- **No persistence logic.** The abstraction stores and restores its own canonical form and nothing else; it performs no storage operations.
- **No provider logic.** The abstraction knows nothing about providers and never references provider concepts.
- **No UI formatting.** The abstraction performs no formatting for display; presentation is owned by the Presentation layer.
- **No product meaning.** The abstraction lives in the Foundation position and carries no business, feature, or product content (DES-001).
- **No Omnia package dependency.** The abstraction sits at the bottom of the dependency graph and introduces no dependency on any Omnia package (ARC-002, ADR-0002).

## 7. Testing Requirements

The abstraction MUST be verified by behavioural tests. The required tests cover:

- **Equality** — identifiers with the same underlying value are equal; identifiers with different underlying values are not; identifiers of different concepts are never equal.
- **Hashability** — equal identifiers produce equal hashes; identifiers behave correctly as dictionary keys and set members.
- **Uniqueness** — generated identifiers are distinct from one another and from restored identifiers; generation is independent of Omnia state and succeeds without connectivity.
- **Serialization** — the canonical form round-trips exactly through restore and serialize; the form is stable across reconstruction; malformed input is rejected and never yields an identifier.
- **Sendability** — identifiers are safe to share across concurrency domains; sharing introduces no mutation and no data race.
- **Immutability** — an identifier's value, canonical form, and equality never change after creation.

Every test MUST be deterministic and independent (TESTING.md, ARC-001).

## 8. Future Evolution

Specialized identities may later derive from the canonical identifier abstraction — for example WorkspaceID, ConversationID, MessageID, ProviderID, AttachmentID, and SessionID — without changing the core API.

Derivation rules:

- A specialized identity is expressed as a typed identifier bound to the concept it identifies, declared by the module that owns the concept (ARC-007).
- Introducing a specialized identity is additive: it declares a new kind and never changes the canonical abstraction or the semantics of existing identifiers.
- A new specialized identity is introduced only when the architecture justifies it, and it is documented before use (PRODUCT_PRINCIPLES — Documentation First).
- Existing identifiers keep their meaning and their serialized form when new specialized identities are introduced.

The core API remains the single shared contract; specialized identities extend it by binding to concepts, never by modification.

## Related Documents

- `Documentation/Design/FOUNDATION_API.md` — the OmniaFoundation public API contract this document realizes.
- `Documentation/Architecture/07_MODULE_STRUCTURE.md` — the modules whose aggregates carry identity.
- `Documentation/Architecture/08_PACKAGE_MODEL.md` — the package model, stability, and boundary rules.
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` — OmniaFoundation's responsibilities and dependencies.
- `Documentation/Product/PRODUCT_PRINCIPLES.md` — the product principles governing identity and ownership.
