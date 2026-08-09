---
title: OmniaInfrastructure Public API Contract
document_id: DES-010
version: 1.1.0
status: Ratified
owner: Founder
project: Omnia
authors:
  - Founder
reviewers:
  - Chief Architect
created: 2026-08-04
last_updated: 2026-08-05
related_documents:
  - Documentation/Product/Roadmap/INFRASTRUCTURE_SPRINT_1_ROADMAP.md
  - Documentation/Product/Roadmap/INFRASTRUCTURE_SPRINT_2_ROADMAP.md
  - Documentation/Design/DOMAIN_API.md
  - Documentation/Design/FOUNDATION_API.md
  - Documentation/Architecture/02_LAYERED_ARCHITECTURE.md
  - Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md
  - Documentation/Architecture/05_LOCAL_STORAGE_ARCHITECTURE.md
  - Documentation/Architecture/06_DEPENDENCY_INJECTION.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - Documentation/Architecture/ADR/ADR-0001-architectural-style.md
  - Documentation/Architecture/ADR/ADR-0002-dependency-direction.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - Documentation/Product/PRODUCT_PRINCIPLES.md
  - project state
supersedes: []
tags:
  - design
  - infrastructure
  - api-specification
  - specification
  - engineering
---

# OmniaInfrastructure Public API Contract

> This document is the normative engineering specification of the public API surface of the OmniaInfrastructure package.
>
> It defines WHAT the package exposes — the contract its consumers depend on. It intentionally does NOT specify implementation.

## 1. Purpose

OmniaInfrastructure is the Infrastructure layer package of Omnia: the implementation of the Domain contracts and the platform services (ARC-009). It realizes the Infrastructure surfaces of the Provider, Storage, Configuration, and Authentication modules (ARC-007, ARC-009). It is the package that implements the contracts declared by the Domain and the package the Composition Root assembles into the application (ARC-002, ADR-0002).

The Infrastructure layer is where platform and provider reality lives (ARC-002). It implements repositories, persistence, networking, keychain access, file system access, and serialization; it provides concrete implementations of the abstractions the Domain declares (ARC-002, ARC-009). Its purpose is not to define what Omnia is — the Domain does that — but to make the declared contracts real: to store what the Domain models, to reach the providers the user connects, and to protect the credentials the user owns (ARC-004, ARC-005).

This document specifies the initial public API inventory, the package responsibility boundaries, the dependency rules, the design principles, the evolution rules, and the ordered sequence in which the contract is implemented. It is derived only from the Infrastructure Sprint 1 Roadmap (`INFRASTRUCTURE_SPRINT_1_ROADMAP.md`), the frozen Domain API contract (`DOMAIN_API.md`, DES-009), the Product Charter (`PRODUCT_CHARTER.md`), the Product Principles (`PRODUCT_PRINCIPLES.md`), and the approved architecture (ARC-002, ARC-004, ARC-005, ARC-006, ARC-008, ARC-009, ADR-0001, ADR-0002). It introduces no concept that the roadmap and the architecture do not establish.

This revision (v1.1.0) extends the provider adapter category of §3.6 with the adapter's concrete capability surface — the three capability call methods, the Domain-to-DTO mapping rules, the error-translation rules, and the streaming lifecycle — exactly as the Infrastructure Sprint 2 Roadmap sequences it (`INFRASTRUCTURE_SPRINT_2_ROADMAP.md` §Requirements). The extension is additive and backward-compatible (§6.3); the existing public API of the frozen Infrastructure API Freeze v1 is unchanged. The concrete capability surface is specified in §3.9 and is the single source of truth for the implementation of the capabilities (PRD-005 Stage 1).

The specification governs the package alone. It defines no behavior of the Foundation, Domain, Application, Presentation, or application-shell layers; those are specified by their own documents.

## 2. Package Responsibilities

### 2.1 What Belongs in OmniaInfrastructure

OmniaInfrastructure owns the Infrastructure-layer content of the modules it realizes (ARC-009). The following belong in the package:

- the concrete implementations of the four Domain repository protocols — Workspace, Conversation, Provider, and Configuration (Storage, DES-009 §3.5);
- the file-based JSON storage engine through which the repositories persist (Storage, ARC-005);
- the aggregate serializers that map the Domain aggregates to and from their stored representation (Storage, ARC-009);
- the secure credential storage implementation of the Domain credential storage protocol, over a platform backend seam (Authentication, DES-009 §3.7, ARC-005);
- the provider transport abstraction and the OpenAI-compatible HTTP client, with their request/response models and serialization (Provider, ARC-004);
- the provider adapters that expose the Domain capability contracts (Provider, DES-009 §3.1, ARC-004).

Everything public in the package is an implementation of a Domain contract and MUST be expressible only in terms the Domain declares (ARC-002, ARC-009). The package implements contracts; it never defines them (ARC-002).

### 2.2 What Must Never Belong in OmniaInfrastructure

The following MUST NEVER enter the package (ARC-002, ARC-009, ADR-0001, ADR-0002):

- business rules, domain logic, or policies — these belong to the Domain and Application layers only (ADR-0001);
- the contracts the package implements — repository protocols, the credential storage protocol, the capability contract, and the provider model are defined by the Domain, never redefined here (ARC-002);
- the user interface, presentation state, or any UI framework (ARC-002);
- use cases, application services, workflow orchestration, and transaction boundaries (ARC-002);
- the Composition Root or any dependency-injection mechanism (ARC-006);
- provider-specific concepts that leak above the adapters — provider APIs never leave the package (ARC-004);
- credential material in any form outside the credential storage backend — credentials never enter logs, request metadata, serializers, or the data store (ARC-001, ARC-004, ARC-005);
- code with no architectural home (ARC-002).

A type that acquires business, UI, provider, or composition meaning is a boundary violation and is re-homed to the layer that owns that concern (DES-001 §2).

## 3. Public API Inventory

The initial public API is organized into the categories below. Each category states its purpose, its intended consumers, its stability expectations, and its ownership. The categories are the contract; the concrete declarations are defined during implementation and MUST conform to this inventory. The categories realize the Infrastructure surfaces defined in the Infrastructure Sprint 1 Roadmap (`INFRASTRUCTURE_SPRINT_1_ROADMAP.md` §Requirements); the concrete capability surface of this revision realizes the capability surface of the Infrastructure Sprint 2 Roadmap (`INFRASTRUCTURE_SPRINT_2_ROADMAP.md` §Requirements).

The public surface of the package is the set of concrete implementations exposed for composition by the Composition Root (ARC-006, ARC-009). No upper package depends on them directly; the Composition Root binds them to the Domain contracts consumers depend on (ARC-009).

### 3.1 Repository Implementations

- **Purpose**: concrete implementations of the four Domain repository protocols — `WorkspaceRepository`, `ConversationRepository`, `ProviderRepository`, and `ConfigurationRepository` (DES-009 §3.5) — persisted through the file-based storage engine (ARC-005).
- **Intended consumers**: the Composition Root, which binds them to the Domain protocols consumed by the Application layer (ARC-006, ARC-009).
- **Stability expectations**: stable. The repositories implement frozen Domain contracts; a breaking change is a replacement, never a revision (ARC-008, DES-009 §6).
- **Ownership**: Storage module (Infrastructure surface, ARC-007).

Normative statements:

- A repository implementation MUST conform exactly to its Domain protocol and MUST store and restore the aggregate as the contract declares, owning no behavior beyond it (DES-009 §3.5, ARC-005).
- Repositories MUST own no business rules; storage never owns business logic (ARC-005).
- Repositories MUST honor user ownership: stored data remains exportable and removable by the user, and credentials are isolated from application data (ARC-005).
- The Provider repository MUST store connection and lifecycle state and MUST NEVER store credentials (DES-009 §3.1, ARC-005).
- The Configuration repository MUST store typed values per level and MUST NEVER store credentials or secrets (DES-009 §3.6, ARC-005).
- Storage failures MUST be translated into the Domain `RepositoryError.storageUnavailable`; no raw storage error crosses the boundary (DES-009 §3.9, ARC-004).

### 3.2 Storage Engine

- **Purpose**: the file-based JSON document store that persists aggregates by identity — save, load, delete, and list — over Foundation file APIs (ARC-005). Storage is a replaceable technology hidden behind the repository protocols (DES-009 §3.5, ARC-005).
- **Intended consumers**: the repository implementations within the package; nothing above the package references it directly (ARC-009).
- **Stability expectations**: stable. The engine is internal to the package; its persistence contract is the stable serialized form (DES-004 §4).
- **Ownership**: Storage module (Infrastructure surface, ARC-007).

Normative statements:

- The storage engine MUST be composed into the repositories and MUST NOT be exposed as a public dependency of the package (ARC-009).
- The engine MUST translate its own failures into `RepositoryError.storageUnavailable`; the Domain failure is the only failure that crosses the boundary (DES-009 §3.9).
- Stored data MUST remain user-owned: readable, exportable, and removable by the user (ARC-005).
- The serialized form MUST be stable across versions and MUST round-trip exactly, so existing stored data keeps its meaning when the package evolves (DES-004 §4, ARC-005).
- The engine MUST NEVER store credentials or secret material (ARC-001, ARC-005).

### 3.3 Aggregate Serializers

- **Purpose**: Infrastructure-owned DTOs and JSON serializers that map the Domain aggregates — which are not Codable — to and from their stored representation (ARC-009). Serialization is the persistence mechanism of the Storage surface; it is internal to the package.
- **Intended consumers**: the repository implementations and the storage engine within the package; never external consumers (ARC-009).
- **Stability expectations**: stable. The serialized form is part of the stored-data contract (DES-004 §4, ARC-005).
- **Ownership**: Storage module (Infrastructure surface, ARC-007).

Normative statements:

- Serializers MUST map the Workspace, Conversation (with message history), Provider, and configuration aggregates exactly as the Domain defines them (DES-009 §3.3–§3.6).
- Serialization MUST be internal to the package; serializers MUST NOT be part of the public surface (ARC-009).
- Serializers MUST NEVER carry or emit credentials; credential references are serialized, never the secrets they point to (ARC-001, ARC-005).
- The serialized form MUST round-trip exactly and remain stable across versions (DES-004 §4, ARC-005).

### 3.4 Secure Credential Storage

- **Purpose**: the concrete implementation of the Domain `CredentialStorageProtocol` (DES-009 §3.7) over a platform backend seam: a Keychain backend on Apple platforms and an in-memory backend for the Linux build and automated tests (ARC-005).
- **Intended consumers**: the Composition Root, which binds it to the Domain protocol consumed by the Application layer and the provider transport (ARC-006, ARC-009).
- **Stability expectations**: stable. The credential boundary is a security invariant (ARC-001, ARC-004, ARC-005).
- **Ownership**: Authentication module (Infrastructure surface, ARC-007).

Normative statements:

- The implementation MUST conform exactly to the Domain protocol, storing `Credential` values under their `CredentialReference` (DES-009 §3.7).
- The implementation MUST honor the contract failures exactly: `credentialNotFound` when no credential is stored for a reference, and `storageUnavailable` when the secure storage cannot be reached (DES-009 §3.9).
- The platform backend seam MUST be replaceable; the Keychain backend serves Apple platforms and the in-memory backend serves the Linux build and tests, with no change to the contract (ARC-005).
- Credentials MUST never leave the device and MUST never enter logs, analytics, or request metadata (ARC-001, ARC-004, ARC-005).
- Credentials MUST be isolated from application data; the data store holds references, never secrets (ARC-005).

### 3.5 Provider Transport and OpenAI-Compatible Client

- **Purpose**: the networking foundation of the Provider module's Infrastructure surface: a `ProviderTransport` protocol that isolates HTTP interaction behind a seam, an OpenAI-compatible HTTP client, the request/response models, JSON serialization, and streaming primitives (ARC-004, ARC-009).
- **Intended consumers**: the provider adapters within the package; nothing above the package references it directly (ARC-009).
- **Stability expectations**: stable. The transport seam is the replaceability boundary for provider connectivity (ARC-001, ARC-006).
- **Ownership**: Provider module (Infrastructure surface, ARC-007).

Normative statements:

- The `ProviderTransport` protocol MUST isolate HTTP interaction so the client and its consumers are testable without a network (ARC-001, ARC-006).
- The OpenAI-compatible client MUST construct requests, decode responses, deliver streaming output, and translate failures for OpenAI-compatible endpoints (PRODUCT_CHARTER, ARC-004).
- Request/response models and serialization MUST be internal DTOs confined to the package (ARC-004).
- Failures MUST be surfaced in the terms the Domain owns; provider and transport failures MUST be translated, never leaked as raw values (DES-009 §3.9, ARC-004).
- Requests MUST use credentials by reference, resolved through the credential storage; secrets MUST never enter logs or request metadata (ARC-001, ARC-005).

### 3.6 Provider Adapters

- **Purpose**: the adapter that conforms to the Domain capability contracts — `TextGenerationContract`, `ConversationContract`, and `StreamingContract` (DES-009 §3.1, ARC-004) — realizing their concrete capability methods over the transport seam (§3.9), and wiring the transport and the credential storage to the contracts the application consumes.
- **Intended consumers**: the Composition Root, which binds them to the Domain capability contracts consumed by the Application layer (ARC-006, ARC-009).
- **Stability expectations**: stable. The adapters implement frozen Domain contracts (ARC-008, DES-009 §6).
- **Ownership**: Provider module (Infrastructure surface, ARC-007).

Normative statements:

- Adapters MUST contain no business logic (ARC-004).
- Adapters MUST expose capabilities in Omnia's terms and MUST surface failures in Domain terms (ARC-004 Adapter Model, DES-009 §3.9).
- Adapters MUST realize the concrete capability methods of the extended Domain capability contract over the transport seam; the concrete surface — the three call methods, the Domain-to-DTO mapping rules, the error-translation rules, and the streaming lifecycle — is specified in §3.9 (DES-009 §3.11.3, PRD-005 Stage 1).
- Live availability MUST be reported by the Infrastructure layer, never by the Domain (ARC-004 Capability Discovery, DES-009 §3.1).
- Provider-specific code MUST be confined to the adapters; provider APIs MUST NOT leak above the package (ARC-004, ARC-009).

### 3.7 Typed Errors

- **Purpose**: explicit, typed failures for the operations that can fail, so errors are never silently swallowed and never leak raw platform or provider values (ARC-001, DES-001 §3.9).
- **Intended consumers**: every consumer of the package; errors cross every internal boundary.
- **Stability expectations**: stable. The error surface is part of the contract (ARC-008).
- **Ownership**: the module that owns the operation's meaning (ARC-007).

Normative statements:

- Failures MUST be represented by typed errors built on the Foundation error abstraction and the Domain error contracts (DES-001 §3.9, DES-009 §3.9); raw platform, storage, or provider errors are never exposed.
- Failures MUST be explicit; no operation fails silently (ARC-001).
- No error with business-rule, presentation, or provider-adapter-external meaning is defined by this package; the failures this package declares are the implementations of the failures the Domain owns — `RepositoryError.storageUnavailable` and `CredentialStorageError` (DES-009 §3.9) — and the translations of transport failures into Domain terms (ARC-004).

### 3.8 Excluded from the Initial Contract

The following are evaluated and intentionally NOT part of the initial public API of OmniaInfrastructure (ARC-009):

- the Composition Root and dependency-injection infrastructure — owned by OmniaApp (ARC-006);
- use cases and application services — owned by OmniaApplication;
- the user interface — owned by OmniaPresentation;
- business rules and domain contracts — owned by OmniaDomain;
- provider capabilities beyond the concrete surface of §3.9 — only the three realized capabilities (Text Generation, Conversation, and Streaming) gain concrete call methods in this contract; the remaining ARC-004 capabilities — Vision, Image Generation, Embeddings, Tool Calling, Structured Output, Audio, and Reasoning — remain extension points and are not realized by this contract (ARC-004, DES-009 §3.1);
- storage technologies beyond the file-based JSON document store — replaceability is preserved by the repository contracts (ARC-005).

A category excluded here is introduced only through the evolution rules of Section 6, never by convenience (ARC-008).

### 3.9 Infrastructure Capability Surface (Frozen)

This subsection records the concrete capability surface of the provider adapter category of §3.6. It is the frozen single source of truth for the implementation of the capabilities (PRD-005 Stage 1, `INFRASTRUCTURE_SPRINT_2_ROADMAP.md` §Implementation Order): the adapter realizes the methods declared here exactly as declared, over the internal OpenAI-compatible client and transport of §3.5. The surface is additive and backward-compatible over Infrastructure API Freeze v1 (§6.3); it adds concrete declarations only and changes no existing public API.

#### 3.9.1 The Concrete Capability Methods

`OpenAICompatibleProviderAdapter` (DES-010 §3.6) conforms to the three Domain capability contracts and realizes their concrete methods (DES-009 §3.11.3):

| Contract (DES-009 §3.1, §3.11.3) | Adapter method |
|---|---|
| `TextGenerationContract` | `generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse` |
| `ConversationContract` | `sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse` |
| `StreamingContract` | `stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error>` |

Normative statements:

- The adapter MUST conform to the three Domain capability contracts and MUST realize the concrete methods exactly as the Domain declares them (DES-009 §3.11.3); it implements contracts, it never defines them (ARC-002, DES-010 §2.1).
- The methods MUST be provider-agnostic at the boundary: they accept and return only the Domain capability value objects (DES-009 §3.11.1); provider-specific request, response, and chunk shapes never cross the package boundary (ARC-004, DES-010 §2.2).
- The adapter owns no business logic and no application state; it composes the internal client of §3.5 and the credential storage of §3.4, and nothing else (ARC-004 Adapter Model, ARC-009).
- Availability reporting (`isAvailable`) is unchanged and remains produced by the Infrastructure layer, never by the Domain (ARC-004 Capability Discovery, DES-009 §3.1).

#### 3.9.2 Domain-to-DTO Mapping Rules

The methods translate the Domain capability types (DES-009 §3.11.1) to and from the internal chat-completions DTOs of §3.5 (`ChatCompletionRequest`, `ChatCompletionResponse`, `ChatCompletionChunk`). The mapping is confined to the adapter's translation layer; the DTOs remain internal to the package (ARC-004, DES-010 §3.5).

Normative statements:

- The text generation request maps to a non-streaming `ChatCompletionRequest`: its `prompt` becomes a single user `ChatMessage`, `ModelReference.name` becomes `model`, and `stream` is `false`.
- The conversation request maps to a non-streaming `ChatCompletionRequest`: its message history becomes the `messages` list (`system`, `user`, and `assistant` roles in order), `ModelReference.name` becomes `model`, and `stream` is `false`.
- The streaming request maps to a streaming `ChatCompletionRequest`: its message history becomes the `messages` list, `ModelReference.name` becomes `model`, and `stream` is `true`.
- A non-streaming response maps back from the first choice's assistant message: the produced `text` of `TextGenerationResponse`, or the assistant `Message` of `ConversationResponse` (DES-009 §3.11.1).
- Each streamed chunk's content delta maps to a `StreamingUpdate.contentDelta` carrying the request identity; the end of the stream maps to the `StreamingUpdate.completion` carrying the assembled assistant `Message` (DES-009 §3.11.3, §3.11.4).
- The mapping MUST NOT alter the Domain vocabulary: requests and responses are expressed only in the existing Domain vocabulary (`Message`, `ModelReference`) and the capability value objects (DES-009 §3.11.1, DES-009 §3.8).
- Provider-specific detail — wire roles, chunk shapes, finish reasons, usage — MUST NOT cross the package boundary (ARC-004, DES-010 §3.5).

#### 3.9.3 Error Translation Rules

Every failure is surfaced in the terms the Domain owns; raw platform, transport, or provider errors are never exposed (ARC-004, DES-009 §3.9, DES-010 §3.7).

Normative statements:

- A credential-resolution failure MUST surface as the existing Domain `CredentialStorageError`; it MUST NOT be wrapped or redefined by `CapabilityError` (DES-009 §3.7, §3.9).
- A transport or decoding failure MUST be translated into the Domain capability errors of DES-009 §3.11.2: `providerUnavailable` when no provider can deliver the requested capability or the provider is unavailable, `invalidRequest` when the capability request cannot be represented, and `invalidResponse` when the capability response could not be decoded.
- The translation from the internal `ProviderTransportError` of §3.7 to the Domain capability errors is confined to the adapter; the internal transport error surface never crosses the package boundary.
- A streaming failure before a terminal event MUST throw `CapabilityError.streamingInterrupted(partialContent:)`, preserving the content received so far; nothing fails silently (ARC-001, DES-009 §3.11.4).

#### 3.9.4 Streaming Lifecycle

The streaming capability delivers the internal client's chunk stream (§3.5) as the Domain streaming updates, honoring the streaming-state invariants of DES-009 §3.3 and §3.11.4.

Normative statements:

- Content deltas MUST be delivered incrementally as `StreamingUpdate.contentDelta`, each carrying its request identity (DES-009 §3.11.1).
- The stream MUST end with the `StreamingUpdate.completion` event carrying the assembled assistant message, so the Application layer can append and persist it (ARC-001, DES-009 §3.3).
- On interruption — cooperative through the stream lifecycle and the Foundation cancellation primitive (DES-008) — the stream MUST end with the `StreamingUpdate.interruption` event carrying the preserved partial content as incomplete; partial content MUST NEVER be silently discarded (ARC-001, DES-009 §3.11.4).
- A cancelled stream ends with the interruption event, never a lost response (DES-008, PRD-005).
- The adapter delivers exactly the events the Domain declares and invents no stream lifecycle of its own (ARC-002, DES-009 §3.11.4).

## 4. Dependency Rules

OmniaInfrastructure occupies the Infrastructure position of the dependency graph (ARC-002, ADR-0002). Its dependency rules are absolute:

- OmniaInfrastructure MUST depend only on OmniaDomain, whose contracts it implements, and on OmniaFoundation among Omnia packages. It declares no other Omnia package dependency (ARC-009).
- OmniaInfrastructure MAY depend on the Swift Standard Library.
- OmniaInfrastructure MAY use OmniaFoundation primitives with no platform coupling (ARC-009): the `Identifier` primitive for identity (DES-002), the clock abstraction where time is required (DES-003), the cancellation primitive for streaming-state interruption (DES-008), and the logging interface — whose concrete implementation it provides (ARC-001, DES-005).
- OmniaInfrastructure MUST NOT depend on Apple platform frameworks in a way that couples the package to a single platform; the package builds and tests on the Linux build environment, and platform-specific behavior — the Keychain backend — is isolated behind the platform backend seam (ARC-005).
- OmniaInfrastructure MUST NOT depend on third-party packages. Native Apple APIs are preferred over third-party libraries (SWIFT.md, PRODUCT_CHARTER).
- OmniaInfrastructure MUST NOT depend on any package of another layer, and MUST NOT reference Presentation, Application, or OmniaApp (ARC-002, ADR-0002).
- Every dependency MUST be declared in the package manifest; hidden dependencies are forbidden (ARC-008).
- The internal type dependency graph MUST be acyclic: the transport, the storage engine, and the serializers are composed into the repositories and adapters, and nothing depends upward (ARC-002, ARC-007, ARC-009).

## 5. API Design Principles

Every public API in OmniaInfrastructure MUST satisfy the following principles. A proposed API that fails any principle is not added (DES-004 §3).

- **Small surface area.** The public API is the smallest intentional contract that satisfies its purpose (ARC-008).
- **Stable contracts.** The public API is the contract; it changes only through the replacement process, never as a silent revision (ARC-008).
- **Explicit ownership.** Every public API has exactly one owner (ARC-007, ARC-008). Ownership is recorded in this inventory.
- **Infrastructure implements; it never defines.** Every public API is an implementation of a Domain contract; the package defines no contract of its own (ARC-002).
- **No business rules.** The package owns no business logic; business rules belong to the Domain and Application layers only (ADR-0001).
- **Provider independence preserved.** Provider-specific code is confined to the adapters, and provider APIs never leak above the package (ARC-004).
- **Replaceable storage.** Storage technology is hidden behind the repository protocols; no public API exposes a storage technology (ARC-005).
- **No UI concerns.** The package contains no user interface or presentation state (ARC-002).
- **Credential isolation.** Credentials never leave the device and never enter logs, serializers, or the data store (ARC-001, ARC-004, ARC-005).
- **Typed, explicit errors.** Failures are represented by typed errors, translated into Domain terms, and never silently swallowed (ARC-001, SWIFT.md).
- **Deterministic behavior.** Time, randomness, and external state are injected or isolated; the transport is testable without a network (ARC-001, ARC-006).
- **Precise naming.** Naming follows the architectural naming guidelines of ARC-003: the suffix of a name states the nature of the element.

## 6. Evolution Rules

### 6.1 When New APIs May Be Added

A public API is added to OmniaInfrastructure only when:

- an existing architectural requirement recorded in the roadmap or the architecture needs it, and no existing API can express it;
- the addition is an implementation of a Domain contract, a new provider adapter, a new storage engine behind the repository protocols, or a new platform backend behind the credential storage seam — never a concept outside the roadmap (ARC-004, ARC-005, ARC-009);
- the addition satisfies every design principle of Section 5 and every responsibility boundary of Section 2;
- the addition is documented before it is used (PRODUCT_PRINCIPLES — Documentation First).

An API with no justified consumer is not added. A concrete capability implementation arrives only when the Domain capability contract is extended (ARC-004, DES-009 §3.1).

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
- The serialized form of stored data MUST remain stable; stored data keeps its meaning when the package evolves (DES-004 §4, ARC-005).
- The dependency graph MUST remain acyclic, and OmniaInfrastructure MUST remain dependent only on OmniaDomain and OmniaFoundation (ARC-002, ADR-0002).
- The initial contract is frozen as **Infrastructure API Freeze v1**; a change to a frozen public API requires a specification revision, and every change to this contract updates this document in the same change (DES-004 §4, PRODUCT_PRINCIPLES — Documentation First).
- The capability surface of this revision is frozen as **Infrastructure Capability Freeze**; from this revision, the concrete capability surface of §3.9 is part of the frozen contract, and a further change to it requires another specification revision, exactly as Infrastructure API Freeze v1 does (PROJECT_STATE.md).

## 7. Initial Implementation Plan

Implementation follows the Infrastructure Sprint 1 Roadmap (`INFRASTRUCTURE_SPRINT_1_ROADMAP.md` §Implementation Order). Each phase:

- introduces only APIs justified by this inventory and the roadmap;
- keeps the package building and its tests green at every step;
- completes with the contract documented and the API covered by tests before any cross-package consumer is added.

### Phase 1 — Storage Engine Foundation

Order: the file-based JSON document store — save, load, delete, and list by identity — with JSON serialization plumbing and storage-error translation to `RepositoryError.storageUnavailable` (§3.2).

### Phase 2 — Aggregate Serializers

Order: the Infrastructure-owned DTOs and JSON serializers for the Workspace, Conversation (with message history), Provider, and configuration aggregates; never credentials (§3.3).

### Phase 3 — Repository Implementations

Order: the Workspace and Conversation repository implementations over the storage engine and serializers, then the Provider repository (connection and lifecycle state, never credentials), then the Configuration repository (typed values per `ConfigurationLevel`, never secrets) (§3.1).

### Phase 4 — Secure Credential Storage

Order: the `CredentialStorageProtocol` implementation with the platform backend seam — the Keychain backend on Apple platforms and the in-memory backend for the Linux build and tests (§3.4).

### Phase 5 — Provider Transport and OpenAI-Compatible Client

Order: the `ProviderTransport` protocol, the OpenAI-compatible HTTP client, the request/response models, JSON serialization, and the streaming primitives (§3.5).

### Phase 6 — Provider Adapters

Order: the adapter shells conforming to the capability contracts, wired to the transport and the credential storage (§3.6).

### Phase 7 — Package Verification

The full verification of the package against the completion criteria of the roadmap: every type covered by deterministic, black-box unit tests (DES-004 §5); the dependency graph limited to OmniaDomain and OmniaFoundation and acyclic; no forbidden dependency imported (no UI, no business rules, no presentation state); no provider API leaks above the package (ARC-002, ARC-004, ARC-008, ARC-009).

No API beyond the categories of Section 3 enters the package in these phases. Each phase ends in a state that is a valid, documented, tested increment of the public contract.

The initial phases (Phase 1 through Phase 7) realize the contract of the frozen Infrastructure API Freeze v1. The capability surface of this revision (v1.1.0) is implemented after those phases, in the order defined by the Infrastructure Sprint 2 Roadmap (`INFRASTRUCTURE_SPRINT_2_ROADMAP.md` §Implementation Order): the capability mapping, then the text generation capability, then the conversation capability, then the streaming capability, then the package verification — with the surface specification frozen before any of its types are implemented (Infrastructure Capability Freeze, `PROJECT_STATE.md`). The implementation realizes exactly the frozen surface of §3.9; a deviation from that surface is a defect and is resolved by correcting the implementation, never by silently changing the surface (DES-004 §1).

## Related Documents

- `Documentation/Product/Roadmap/INFRASTRUCTURE_SPRINT_1_ROADMAP.md` — the roadmap that sequences this contract.
- `Documentation/Product/Roadmap/INFRASTRUCTURE_SPRINT_2_ROADMAP.md` — the roadmap that sequences the capability surface of this revision.
- `Documentation/Design/DOMAIN_API.md` — the frozen Domain contract this package implements.
- `Documentation/Design/FOUNDATION_API.md` — the parent contract of the package this package depends on.
- `Documentation/Architecture/02_LAYERED_ARCHITECTURE.md`
- `Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md`
- `Documentation/Architecture/05_LOCAL_STORAGE_ARCHITECTURE.md`
- `Documentation/Architecture/06_DEPENDENCY_INJECTION.md`
- `Documentation/Architecture/08_PACKAGE_MODEL.md`
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md`
- `Documentation/Architecture/ADR/ADR-0001-architectural-style.md`
- `Documentation/Architecture/ADR/ADR-0002-dependency-direction.md`
- `Documentation/Product/PRODUCT_CHARTER.md`
- `Documentation/Product/PRODUCT_PRINCIPLES.md`
- `project state`
