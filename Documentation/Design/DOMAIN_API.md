---
title: OmniaDomain Public API Contract
document_id: DES-009
version: 0.3.0
status: Ratified
owner: Founder
project: Omnia
authors:
  - Founder
reviewers:
  - Chief Architect
created: 2026-08-03
last_updated: 2026-08-05
related_documents:
  - Documentation/Product/Roadmap/DOMAIN_SPRINT_1_ROADMAP.md
  - Documentation/Product/Roadmap/DOMAIN_SPRINT_2_ROADMAP.md
  - Documentation/Design/FOUNDATION_API.md
  - Documentation/Design/API/API_DESIGN_GUIDELINES.md
  - Documentation/Design/API/IDENTIFIER_API.md
  - Documentation/Design/API/CLOCK_API.md
  - Documentation/Design/API/LIFECYCLE_API.md
  - Documentation/Design/API/CANCELLATION_API.md
  - Documentation/Architecture/02_LAYERED_ARCHITECTURE.md
  - Documentation/Architecture/03_MODULE_MODEL.md
  - Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md
  - Documentation/Architecture/05_LOCAL_STORAGE_ARCHITECTURE.md
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - Documentation/Architecture/ADR/ADR-0001-architectural-style.md
  - Documentation/Architecture/ADR/ADR-0002-dependency-direction.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - Documentation/Product/PRODUCT_PRINCIPLES.md
  - .ai/context/PROJECT_STATE.md
supersedes: []
tags:
  - design
  - domain
  - api-specification
  - specification
  - engineering
---

# OmniaDomain Public API Contract

> This document is the normative engineering specification of the public API surface of the OmniaDomain package.
>
> It defines WHAT the package exposes — the contract its consumers depend on. It intentionally does NOT specify implementation.

## 1. Purpose

OmniaDomain is the Domain layer package of Omnia: the business rules, entities, value objects, domain services, policies, and provider-agnostic contracts (ARC-009). It realizes the Domain surfaces of the Provider, Storage, Configuration, Authentication, Workspace, and Conversation modules (ARC-007, ARC-009). It is the package the Application layer depends on and the package whose contracts the Infrastructure layer implements (ARC-002, ADR-0002).

The Domain layer is what keeps Omnia platform-independent: it imports no UI, no networking, no persistence, and no provider implementation (ARC-002, ADR-0001, ADR-0002). Its contracts are the reason providers are interchangeable and storage is replaceable (PRODUCT_PRINCIPLES — Provider Independence, Long-Term Thinking).

This document specifies the initial public API inventory, the package responsibility boundaries, the dependency rules, the design principles, the evolution rules, and the ordered sequence in which the contract is implemented. It is derived only from the Domain Sprint 1 Roadmap (`DOMAIN_SPRINT_1_ROADMAP.md`), the Product Charter (`PRODUCT_CHARTER.md`), the Product Principles (`PRODUCT_PRINCIPLES.md`), and the approved architecture (ARC-002, ARC-003, ARC-004, ARC-005, ARC-007, ARC-008, ARC-009, ADR-0001, ADR-0002). It introduces no concept that the roadmap and the architecture do not establish.

This revision (v0.3.0) extends the capability contract of §3.1 with the capability value objects, the concrete capability methods on the three realized capability contracts, the capability errors of §3.9, and the streaming behavior of §3.3, exactly as the Domain Sprint 2 Roadmap sequences it (`DOMAIN_SPRINT_2_ROADMAP.md` §Requirements). The extension is additive and backward-compatible (§6.3); the existing public API of the frozen Domain API Freeze v1 is unchanged. The concrete design of the extension — the value-object inventory, the error taxonomy, the contract-method signatures, and the streaming state machine — is frozen in §3.11 and is the single source of truth for the implementation of the extension (PRD-004 Stage 2).

The specification governs the package alone. It defines no behavior of the Foundation, Application, Infrastructure, Presentation, or application-shell layers; those are specified by their own documents.

## 2. Package Responsibilities

### 2.1 What Belongs in OmniaDomain

OmniaDomain owns the Domain-layer content of the modules it realizes (ARC-009). The following belong in the package:

- the capability contract and the provider model (Provider);
- the data model and the repository protocols for stored aggregates (Storage);
- the configuration model, its defaults, and its levels (Configuration);
- the credential storage protocol and credential references (Authentication);
- the workspace aggregates and the workspace repository protocol (Workspace);
- the conversation aggregates and message value objects (Conversation);
- the domain services and policies owned by these modules: provider lifecycle and selection, and configuration resolution.

Everything public in the package MUST be expressible without reference to a platform, a provider, a storage technology, or a user interface (ARC-002).

### 2.2 What Must Never Belong in OmniaDomain

The following MUST NEVER enter the package (ARC-002, ARC-009, ADR-0001, ADR-0002):

- SwiftUI or any UI framework; presentation state or navigation;
- networking and transport;
- persistence implementations, storage engines, serializers, and database technology;
- provider implementations, provider adapters, and provider APIs;
- keychain and secure-storage implementations;
- use cases, application services, workflow orchestration, and transaction boundaries;
- the Composition Root or any dependency-injection mechanism (ARC-006);
- code with no architectural home (ARC-002).

A type that acquires a platform, provider, storage, or UI dependency is a boundary violation and is re-homed to the layer that owns that concern (DES-001 §2).

## 3. Public API Inventory

The initial public API is organized into the categories below. Each category states its purpose, its intended consumers, its stability expectations, and its ownership. The categories are the contract; the concrete declarations are defined during implementation and MUST conform to this inventory. The categories realize the domain model defined in the Domain Sprint 1 Roadmap (`DOMAIN_SPRINT_1_ROADMAP.md` §Requirements); the capability-contract extension of this revision realizes the capability extension of the Domain Sprint 2 Roadmap (`DOMAIN_SPRINT_2_ROADMAP.md` §Requirements).

### 3.1 Provider Contracts

- **Purpose**: the provider-agnostic capability contract and the provider model. The application depends on capabilities, never on providers (ARC-004). This is the product's Provider Independence invariant expressed as a contract (PRODUCT_PRINCIPLES).
- **Intended consumers**: the Conversation model (request and streaming flows), the Workspace model (selection), the Application layer (orchestration), and OmniaInfrastructure (adapters implement the contract).
- **Stability expectations**: stable. The contract is the interchangeability seam; a breaking change is a replacement, never a revision (ARC-008).
- **Ownership**: Provider module (Domain surface, ARC-007).

The category comprises:

- **Capability contract** — the provider-agnostic contract through which providers are consumed. It defines what the application needs, in the application's own terms (ARC-004 Capability Model).
- **Capability set** — the capabilities defined by ARC-004. The capabilities realized by this contract are **Text Generation**, **Conversation**, and **Streaming**, grounded in the Product Charter In Scope (an OpenAI-compatible client with streaming responses) and the conversation flows of ARC-001. The remaining ARC-004 capabilities — **Vision**, **Image Generation**, **Embeddings**, **Tool Calling**, **Structured Output**, **Audio**, and **Reasoning** — are declared by the contract as extension points and are not realized by this contract (ARC-004, ARC-007).
- **Provider model** — the provider connection the user has configured (ARC-004 Provider Model): identity, capabilities, configuration, availability, metadata, limits, and versioning. Authentication is realized by credential reference; the model MUST NOT contain credentials (ARC-004, ARC-005).
- **Value objects** — `ProviderIdentity`, a stable identity within the application built on the Foundation `Identifier` primitive (DES-002) and the shared identity used for cross-aggregate references; `ModelReference`, the named model a provider offers, used by provider and model selection (ARC-001, ARC-004); `ProviderCapabilities`, the set of capabilities a provider can deliver (ARC-004); `ProviderMetadata`, descriptive provider information (ARC-004); `ProviderLimits`, constraints on usage such as rates and maximums (ARC-004).
- **Capability value objects** — the provider-agnostic request, response, and streaming value objects the concrete methods operate on, expressed in the existing Domain vocabulary (`Message`, `ModelReference`, §3.8): a text generation request (the prompt and the requested model) and a text generation response (the produced text); a conversation request (the message history and the requested model) and a conversation response (the assistant's reply, expressed as the existing `Message` value object so it appends to the history); a streaming request (the message history and the requested model) and the streaming updates — the incremental delivery events: content deltas, the completion event carrying the assembled assistant message, and the interruption event carrying the preserved partial content (ARC-004, ARC-001, DES-009 §3.3, §3.8).
- **Capability methods** — the concrete, provider-agnostic methods that realize the three realized capability contracts: a text generation method that produces text from a text generation request and returns the text generation response; a conversation method that sends the conversation request (the message history) and returns the conversation response, the assistant `Message` to append to the history; and a streaming method that returns the stream of streaming updates — the stream delivers content deltas, ends with the completion event carrying the assembled assistant message, and on interruption ends with the interruption event carrying the preserved partial content. Each method is `async throws`, typed against the capability value objects, and expresses its failures in the capability errors (§3.9) (ARC-004, ARC-001, DES-009 §3.9).

Normative statements:

- The capability contract MUST be provider-agnostic; it MUST NOT reference any provider.
- A capability is realized only by extending the capability contract; capabilities MUST NOT be added outside the contract (ARC-004, ARC-007).
- The provider model MUST record declared capabilities and metadata; live availability is discovered and reported by the Infrastructure layer, never by the Domain (ARC-004 Capability Discovery).
- The capability methods MUST be provider-agnostic and typed against the capability value objects; they MUST NOT reference any provider, and the implementation of the methods belongs to the Infrastructure layer, never to the Domain (ARC-002, ARC-004, ARC-009).
- The capability value objects MUST be immutable and equal by content (ARC-003), MUST carry their typed identities and model references built on the Foundation primitives (DES-002, DES-004), and MUST NOT contain any provider-specific concept (ARC-004).
- The streaming method MUST deliver content incrementally and MUST end with a completion event carrying the assembled assistant message or, on interruption, an interruption event carrying the preserved partial content; partial content MUST NEVER be silently discarded (ARC-001, DES-009 §3.3).

### 3.2 Provider Lifecycle and Selection

- **Purpose**: the explicit provider lifecycle and selection strategy of ARC-004.
- **Intended consumers**: the Application layer (provider management), OmniaInfrastructure (initialization and adapters), and the Presentation layer (availability display).
- **Stability expectations**: stable. The lifecycle states and the selection priority are architecture constants (ARC-004).
- **Ownership**: Provider module (Domain surface, ARC-007).

The category comprises:

- **Provider lifecycle service** — owns the provider lifecycle state machine: Registered, Validated, Initializing, Ready, Unavailable, Disabled, Removed (ARC-004). State transitions are the only way a provider changes status (ARC-004). The service is realized on the Foundation `Lifecycle` primitive (DES-007); provider-specific states are defined by this package, never by the primitive.
- **Provider selection service and policy** — applies the selection strategy: User Selection, then Workspace Preference, then Capability Preference, then Automatic Selection, then Failure (ARC-004). The selection result is the selected provider and model (ARC-001).

Normative statements:

- An invalid lifecycle transition MUST be rejected with an explicit typed failure; it MUST NOT be silently applied (DES-007, ARC-004).
- When no provider can deliver the required capability, the selection result MUST be an explicit failure, never silent degradation (ARC-004).
- The selection policy MUST honor the documented priority; the user's explicit choice always wins (ARC-004).

### 3.3 Conversation Model

- **Purpose**: conversations and message history, including the streaming-state invariants of the conversation workflow (ARC-001 Conversation Engine, ARC-007).
- **Intended consumers**: the Application layer (conversation services), OmniaInfrastructure (persistence through the conversation repository), the Presentation layer (rendering), and the Provider contract (request and streaming flows).
- **Stability expectations**: stable. Conversations and messages are user-owned content (ARC-005).
- **Ownership**: Conversation module (Domain surface, ARC-007).

The category comprises:

- **Conversation aggregate** — a recorded interaction with identity and continuity (ARC-003 Entity). It owns its message history and its streaming state (ARC-007).
- **Message value object** — an individual contribution to a conversation; message value objects are owned by the Conversation module (ARC-007, ARC-009).
- **Streaming behavior** — the capability-streaming behavior of the extended contract (§3.1): a streaming request carries the message history; the stream delivers the assistant's reply incrementally as content deltas; the completion event carries the assembled assistant message so the Application layer can append and persist it; an interruption event carries the preserved partial content. Interruption is cooperative through the stream lifecycle and the Foundation cancellation primitive (DES-008); it preserves partial content as incomplete and requires no provider-specific concept (ARC-001 Streaming Interrupted, DES-009 §3.3).

Normative statements:

- Messages are immutable value objects; a change produces a new value, never an in-place mutation (ARC-001 Immutable Domain Models, ARC-003).
- Streaming-state invariants follow the failure philosophy of ARC-001: interruption marks partial content as incomplete and MUST NOT silently discard it; the full history is always preserved (ARC-001 Streaming Interrupted).
- Streaming interruption MUST preserve the partial content already received and mark it incomplete; it MUST NEVER silently discard it (ARC-001).
- The full conversation history MUST always be preserved; the completion event MUST carry the assembled assistant message so the Application layer can append and persist it (ARC-001, DES-009 §3.3).
- Streaming interruption MUST be cooperative through the stream lifecycle and the Foundation cancellation primitive (DES-008); it MUST NOT require any provider-specific concept (DES-009 §4).
- Conversation content is user-owned data (ARC-005); the aggregate enforces no behavior beyond its own invariants and owns no provider or storage behavior.

### 3.4 Workspace Model

- **Purpose**: the organization of the user's work across conversations and providers (ARC-001 Workspace, ARC-007).
- **Intended consumers**: the Application layer (workspace services), OmniaInfrastructure (persistence through the workspace repository), and the Presentation layer.
- **Stability expectations**: stable. Workspaces are user-owned data (ARC-005).
- **Ownership**: Workspace module (Domain surface, ARC-007).

The category comprises:

- **Workspace aggregate** — the unit of organization with identity and continuity (ARC-003 Entity). It manages workspace membership of conversations and providers (ARC-007).

Normative statements:

- Membership of conversations and providers is managed by identity, never by embedding the aggregates themselves; this is what keeps the internal dependency graph acyclic (ARC-007).
- Workspace preferences and provider overrides belong to the configuration model and MUST NOT be embedded in the aggregate (ARC-004, ARC-007).

### 3.5 Repository Contracts

- **Purpose**: declared data access for the stored aggregates (ARC-003 Repository, ARC-005, ARC-007, ARC-009). The repository protocols are the Domain surface of the Storage module.
- **Intended consumers**: the Application layer and domain services; the concrete implementations are provided by OmniaInfrastructure and delivered by the Composition Root (ARC-006).
- **Stability expectations**: stable. The protocols are contracts; changing them is replacement, never revision (ARC-008).
- **Ownership**: Storage module (Domain surface, ARC-007, ARC-009).

The category comprises repository protocols for each stored aggregate of the roadmap:

- `WorkspaceRepository` — the Workspace aggregate.
- `ConversationRepository` — the Conversation aggregate and its message history.
- `ProviderRepository` — the Provider model.
- `ConfigurationRepository` — the configuration model.

Normative statements:

- A repository protocol MUST hide the storage implementation; consumers depend on the protocol, never on a storage technology (ARC-003).
- Repository contracts MUST honor user ownership: stored data remains exportable and removable by the user, and credentials are isolated from application data (ARC-005).
- Repository protocols MUST NOT own business rules; storage never owns business logic (ARC-005).
- Repository protocols are contracts; implementations belong to OmniaInfrastructure and are out of scope for this package (ARC-002, ARC-009).

### 3.6 Configuration Model

- **Purpose**: user-owned configuration values with defaults and explicit levels (ARC-001, ARC-003 Configuration, ARC-007, ARC-009).
- **Intended consumers**: every module allowed to depend on configuration, and OmniaInfrastructure (persistence).
- **Stability expectations**: stable. Configuration is user-owned (PRODUCT_PRINCIPLES — User Ownership).
- **Ownership**: Configuration module (Domain surface, ARC-007).

The category comprises:

- **Typed configuration protocol** — typed value access with defaults (ARC-007, ARC-009). The protocol holds values and defaults; it contains no business logic (ARC-003).
- **Configuration levels** — provider settings, workspace overrides, global defaults, and capability preferences (ARC-004).
- **Configuration resolution policy** — the pure decision rule that resolves configuration levels in order: provider settings, then workspace overrides, then global defaults, then capability preferences (ARC-004).

Normative statements:

- Configuration is user-owned; sensible defaults reduce the need for configuration (PRODUCT_PRINCIPLES — Simplicity Wins).
- The resolution policy MUST be pure and deterministic; it depends on no external state (ARC-003 Policy).
- The typed configuration protocol MUST NOT embed product decisions (ARC-003).

### 3.7 Authentication Contract

- **Purpose**: credential storage and credential references, keeping secrets separate from the data they protect (ARC-001 Security, ARC-004 Authentication Model, ARC-005).
- **Intended consumers**: OmniaInfrastructure (adapters and secure-storage implementation), the Settings surface, and the Application layer.
- **Stability expectations**: stable. The credential boundary is a security invariant (ARC-001, ARC-004, ARC-005).
- **Ownership**: Authentication module (Domain surface, ARC-007).

The category comprises:

- **Credential storage protocol** — store, retrieve, and remove credentials by reference (ARC-007, ARC-009).
- **Credential reference value object** — a pointer to credentials held in secure storage; never the credentials themselves (ARC-005, ARC-009).

Normative statements:

- Credentials MUST never leave the device (ARC-001, ARC-004, ARC-005).
- Secrets MUST never enter logs or analytics (ARC-001).
- Providers own authentication; Omnia owns credential storage; the contract keeps the two separate (ARC-004).
- The protocol is a contract; secure-storage implementation belongs to OmniaInfrastructure (ARC-009).

### 3.8 Value Objects

- **Purpose**: the immutable, content-equal vocabulary of the Domain (ARC-003 Value Object, ARC-001 Immutable Domain Models).
- **Intended consumers**: the whole package and its consumers; value objects cross every internal boundary.
- **Stability expectations**: stable. Value objects are immutable once created; changes produce new values (ARC-001).
- **Ownership**: the module that owns each value's meaning (ARC-007): Conversation owns `Message`; Provider owns `Capability`, `ProviderIdentity`, `ModelReference`, `ProviderCapabilities`, `ProviderMetadata`, `ProviderLimits`, and the capability value objects of §3.1 — the text generation, conversation, and streaming requests and responses and the streaming updates; Authentication owns `CredentialReference`; Configuration owns the configuration values and levels.

Normative statements:

- A value object MUST be immutable and MUST define equality by content (ARC-003).
- Value objects MUST NOT carry identity, mutable state, or behavior beyond their value (ARC-003).
- Identity values MUST be typed, never raw values (DES-004 — Strong typing); each aggregate carries its own typed identity, and cross-aggregate references use those identities, built on the Foundation `Identifier` primitive (DES-002).
- The capability value objects MUST be expressed only in the existing Domain vocabulary (`Message`, `ModelReference`) and the Foundation primitives; they MUST NOT depend on the capability contracts they extend (ARC-002, ARC-007, ARC-009).

### 3.9 Typed Errors

- **Purpose**: explicit, typed failures for the domain operations that can fail, so errors are never silently swallowed (ARC-001, DES-001 §3.9).
- **Intended consumers**: every consumer of the package; errors cross every internal boundary.
- **Stability expectations**: stable. The error surface is part of the contract (ARC-008).
- **Ownership**: the module that owns the operation's meaning (ARC-007).

The contract declares typed failures for:

- provider selection — when no provider can deliver the required capability (ARC-004);
- provider lifecycle transitions — when a transition is invalid or the provider is unknown (ARC-004, DES-007);
- conversation streaming interruption — when a stream ends before completion (ARC-001);
- repository operations — when the storage backing a repository cannot be reached (`RepositoryError.storageUnavailable`);
- credential storage — when no credential is stored for a reference, or the secure storage cannot be reached (`CredentialStorageError`);
- capability operations — when a provider cannot deliver a requested capability, or the capability response could not be decoded, in Domain terms — the capability-level abstraction of a failed contract, exactly as `RepositoryError.storageUnavailable` abstracts a failed repository (ARC-004, DES-009 §3.9).

Normative statements:

- Failures MUST be represented by typed errors built on the Foundation error abstraction (DES-001 §3.9); raw error values are never exposed.
- Failures MUST be explicit; no domain operation fails silently (ARC-001).
- No error with provider-adapter, storage-engine, or UI meaning is defined by this package: the Domain never declares the failures of a concrete provider, a concrete storage technology, or a user interface, which belong to the Infrastructure and Presentation layers (ARC-004, ARC-009). The storage-unavailable failures of the repository and credential-storage contracts are Domain-owned abstractions of a failed contract; they carry no storage-technology detail and never carry credential material.
- The capability error MUST be the Domain-owned abstraction of a failed capability contract: it declares, in Domain terms, that a provider cannot deliver the requested capability or that the capability response could not be decoded, and it MUST carry no provider, transport, or decoding detail (ARC-004, DES-009 §3.9).
- Credential-resolution failures of the capability operations MUST surface as the existing `CredentialStorageError`; they MUST NOT be wrapped or redefined by the capability error (DES-009 §3.7, §3.9).

### 3.10 Excluded from the Initial Contract

The following are evaluated and intentionally NOT part of the initial public API of OmniaDomain (ARC-009):

- use cases and application services — owned by OmniaApplication;
- provider adapters and networking — owned by OmniaInfrastructure;
- persistence engines, migration, indexes, caches, and serializers — owned by OmniaInfrastructure;
- keychain and secure-storage implementation — owned by OmniaInfrastructure;
- user interface concerns — owned by OmniaPresentation;
- the Composition Root and dependency-injection infrastructure — owned by OmniaApp (ARC-006);
- planned capability concepts that are future extension points, not yet specified: Attachments, Prompt Library, Voice, and Plugins (ARC-001).

A category excluded here is introduced only through the evolution rules of Section 6, never by convenience (ARC-008).

### 3.11 Domain Capability Design (Frozen)

This subsection records the concrete design of the capability extension of §3.1, §3.3, §3.8, and §3.9. It is the frozen single source of truth for the implementation of the extension (PRD-004 Stage 2, `DOMAIN_SPRINT_2_ROADMAP.md` §Implementation Order): the types and methods declared here are realized exactly as declared by the implementation issues that follow it. The design is additive and backward-compatible over Domain API Freeze v1 (§6.3); it adds new declarations only and changes no existing public API.

#### 3.11.1 Capability Value Objects

The value objects of the three realized capabilities (§3.1, §3.8), all immutable, equal by content, `Equatable` and `Sendable` (ARC-003):

| Type | Nature | Content |
|---|---|---|
| `CapabilityRequestIdentity` | `Identifier<CapabilityRequestIdentityKind>` (DES-002) | The typed identity of a capability request, used to correlate a response or a streaming update to its request. |
| `TextGenerationRequest` | value object | `identity: CapabilityRequestIdentity`, `prompt: String`, `model: ModelReference`. |
| `TextGenerationResponse` | value object | `text: String` — the produced text. |
| `ConversationRequest` | value object | `identity: CapabilityRequestIdentity`, `history: [Message]`, `model: ModelReference`. |
| `ConversationResponse` | value object | `message: Message` — the assistant's reply, to be appended to the history. |
| `StreamingRequest` | value object | `identity: CapabilityRequestIdentity`, `history: [Message]`, `model: ModelReference`. |
| `StreamingUpdate` | value object (enum) | The incremental delivery events of §3.1: `contentDelta` carrying a content fragment; `completion` carrying the assembled assistant `Message`; `interruption` carrying the preserved partial content. Every event carries its request identity. |

Normative statements:

- Every request carries a `CapabilityRequestIdentity` built on the Foundation `Identifier` primitive (DES-002) and a `ModelReference`; raw identity or model values are never used (DES-004 — Strong typing).
- The value objects depend only on the existing Domain vocabulary (`Message`, `ModelReference`), `CapabilityRequestIdentity`, and the Foundation primitives; they MUST NOT depend on the capability contracts they extend (DES-009 §3.8).
- The value objects contain no provider-specific concept (ARC-004).
- `StreamingUpdate` events carry the request identity so a consumer can correlate an event to its in-flight request.

#### 3.11.2 Capability Errors

The typed failure surface of the capability operations (§3.9), built on the Foundation error abstraction (DES-001 §3.9) and `Equatable` and `Sendable`:

| Error | Meaning |
|---|---|
| `CapabilityError.providerUnavailable` | No provider can deliver the requested capability, or the provider is unavailable (ARC-004). |
| `CapabilityError.invalidRequest` | The capability request is invalid in Domain terms. |
| `CapabilityError.invalidResponse` | The capability response could not be decoded (ARC-004). |
| `CapabilityError.streamingInterrupted(partialContent:)` | A stream ended before completion and its interruption event could not be delivered; the partial content received so far is preserved, never discarded (ARC-001). |

Normative statements:

- `CapabilityError` carries no provider, transport, or decoding detail (DES-009 §3.9).
- Credential-resolution failures of the capability operations surface as the existing `CredentialStorageError`; they are never wrapped or redefined by `CapabilityError` (DES-009 §3.7, §3.9).
- `streamingInterrupted` preserves the partial content received so far; it is never silently discarded (ARC-001).

#### 3.11.3 Concrete Contract Methods

The concrete methods that realize the three capability contracts (§3.1):

| Contract | Method |
|---|---|
| `TextGenerationContract` | `generateText(from request: TextGenerationRequest) async throws -> TextGenerationResponse` |
| `ConversationContract` | `sendMessage(_ request: ConversationRequest) async throws -> ConversationResponse` |
| `StreamingContract` | `stream(_ request: StreamingRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error>` |

Normative statements:

- The methods are provider-agnostic and typed against the capability value objects; they reference no provider (ARC-004).
- The contracts remain protocol-only declarations; the implementation of the methods belongs to the Infrastructure adapters, never to the Domain (ARC-009, DES-009 §2.1).
- Every failure is expressed in the capability errors of §3.11.2; nothing fails silently (ARC-001).
- The streaming method returns an async sequence of streaming updates: content deltas delivered incrementally, ending with the completion event carrying the assembled assistant message or, on interruption, the interruption event carrying the preserved partial content (ARC-001, DES-009 §3.3).

#### 3.11.4 Streaming State Machine

The streaming lifecycle of the extended contract (§3.3). The states are **active**, **complete**, and **interrupted**. The legal transitions are:

- `active → active` — the stream continues delivering content deltas.
- `active → complete` — terminal: the stream ends with the completion event carrying the assembled assistant message.
- `active → interrupted` — terminal: the stream ends with the interruption event carrying the preserved partial content; interruption is cooperative through the stream lifecycle and the Foundation cancellation primitive (DES-008).
- `complete` and `interrupted` are terminal — no transition leaves them. Resumption after interruption is a new stream, a new request with a new identity, that starts from the preserved partial content; the Conversation aggregate carries the partial content forward (`beginStreaming` from `.interrupted`, Domain API Freeze v1).

Failure path: when a stream fails before any terminal event can be delivered, it throws `CapabilityError.streamingInterrupted(partialContent:)`, preserving the content received so far (ARC-001).

Normative statements:

- Partial content is never silently discarded; an interruption always carries the preserved partial content as incomplete (ARC-001).
- Completion always carries the assembled assistant message so the Application layer can append and persist it (ARC-001, DES-009 §3.3).
- The stream-level state machine (active, complete, interrupted) is the capability-stream contract; the Conversation aggregate's frozen state machine (idle, streaming, interrupted) records the same lifecycle at the aggregate level, and the two are consistent (DES-009 §3.3, ARC-001).
- The state machine requires no provider-specific concept (DES-009 §4).

## 4. Dependency Rules

OmniaDomain occupies the Domain position of the dependency graph (ARC-002, ADR-0002). Its dependency rules are absolute:

- OmniaDomain MUST depend only on OmniaFoundation among Omnia packages. It declares no other Omnia package dependency (ARC-009).
- OmniaDomain MAY depend on the Swift Standard Library.
- OmniaDomain MAY use OmniaFoundation primitives with no platform coupling (ARC-009): the `Identifier` primitive for identity (DES-002), the `Lifecycle` primitive for the provider lifecycle (DES-007), the clock abstraction where time is required (DES-003), the cancellation primitive for streaming-state interruption (DES-008), and the version value type for provider versioning (ARC-004, DES-001 §3.8).
- OmniaDomain MUST NOT depend on Apple platform frameworks, third-party packages, or any package of another layer (ARC-002, ARC-009).
- Every dependency MUST be declared in the package manifest; hidden dependencies are forbidden (ARC-008).
- The internal type dependency graph MUST be acyclic: aggregates reference one another by identity only, and aggregates MUST NOT depend on the repository protocols that persist them (dependency inversion, ARC-002, ARC-007).

## 5. API Design Principles

Every public API in OmniaDomain MUST satisfy the following principles. A proposed API that fails any principle is not added (DES-004 §3).

- **Small surface area.** The public API is the smallest intentional contract that satisfies its purpose (ARC-008).
- **Stable contracts.** The public API is the contract; it changes only through the replacement process, never as a silent revision (ARC-008).
- **Explicit ownership.** Every public API has exactly one owner (ARC-007, ARC-008). Ownership is recorded in this inventory.
- **The Domain owns the business rules.** Business rules belong to the Domain and Application layers only (ADR-0001); the package owns its rules and imports none from other layers.
- **Provider independence.** Capabilities never depend on providers; no provider-specific code enters the package (ARC-004).
- **No storage implementations.** The package declares contracts; persistence and its technology belong to Infrastructure (ARC-002, ARC-005).
- **No UI concerns.** The package contains no user interface or presentation state (ARC-002).
- **Value semantics where practical.** Value objects and state models are immutable; changes produce new values. Entities are the exception: identity and continuity require reference semantics (ARC-001, ARC-003, SWIFT.md).
- **Typed, explicit errors.** Failures are represented by typed errors and are never silently swallowed (ARC-001, SWIFT.md).
- **Deterministic behavior.** Time, randomness, and external state are injected or isolated (ARC-001).
- **Precise naming.** Naming follows the architectural naming guidelines of ARC-003: the suffix of a name states the nature of the element.

## 6. Evolution Rules

### 6.1 When New APIs May Be Added

A public API is added to OmniaDomain only when:

- an existing architectural requirement recorded in the roadmap or the architecture needs it, and no existing API can express it;
- the addition is a capability that extends the capability contract, a new policy, or a new repository protocol for a future stored aggregate — never a concept outside the roadmap (ARC-004, ARC-007);
- the addition satisfies every design principle of Section 5 and every responsibility boundary of Section 2;
- the addition is documented before it is used (PRODUCT_PRINCIPLES — Documentation First).

An API with no justified consumer is not added. A planned capability — such as an Attachment or Prompt aggregate — enters only when its product requirement is specified (ARC-001 extension points).

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
- The capability contract remains extensible: realizing a new capability extends the contract and never changes the realized capabilities (ARC-004, ARC-007).
- The dependency graph MUST remain acyclic, and OmniaDomain MUST remain dependent only on OmniaFoundation (ARC-002, ADR-0002).
- The initial contract is frozen as **Domain API Freeze v1**; a change to a frozen public API requires a specification revision, and every change to this contract updates this document in the same change (DES-004 §4, PRODUCT_PRINCIPLES — Documentation First).
- The capability extension of this revision is frozen as **Domain Capability Contract Extension Freeze**; from this revision, the extension is part of the frozen contract, and a further change to it requires another specification revision, exactly as Domain API Freeze v1 does (PROJECT_STATE.md).

## 7. Initial Implementation Plan

The initial implementation follows the Domain Sprint 1 Roadmap (`DOMAIN_SPRINT_1_ROADMAP.md` §Implementation Order). Each phase:

- introduces only APIs justified by this inventory and the roadmap;
- keeps the package building and its tests green at every step;
- completes with the contract documented and the API covered by tests before any cross-package consumer is added.

The initial phases (Phase 1 through Phase 8) realize the contract of the frozen Domain API Freeze v1. The capability extension of this revision (v0.3.0) is implemented after those phases, in the order defined by the Domain Sprint 2 Roadmap (`DOMAIN_SPRINT_2_ROADMAP.md` §Implementation Order): the capability value objects, then the capability errors, then the concrete methods on `TextGenerationContract`, `ConversationContract`, and `StreamingContract`, then the package verification — with the extension specification frozen before any of its types are implemented (Domain Capability Contract Extension Freeze, `PROJECT_STATE.md`). The implementation realizes exactly the frozen design of §3.11; a deviation from that design is a defect and is resolved by correcting the implementation, never by silently changing the design (DES-004 §1).

### Phase 1 — Value Objects and Shared Vocabulary

Order: the value objects of §3.8 — `Message`, `Capability`, `ProviderIdentity`, `ModelReference`, `ProviderCapabilities`, `ProviderMetadata`, `ProviderLimits`, `CredentialReference`, and the configuration values and levels. Built on the OmniaFoundation primitives of Section 4.

### Phase 2 — Capability Contract and Provider Model

Order: the extensible capability contract and the provider model of §3.1.

### Phase 3 — Configuration Model

Order: the typed configuration protocol, the configuration levels, and the configuration resolution policy of §3.6.

### Phase 4 — Credential Storage Protocol

Order: the Authentication contract of §3.7, with the `CredentialReference` value object.

### Phase 5 — Aggregates

Order: the Workspace, Provider, and Conversation aggregates of §3.2–§3.4. The Provider aggregate's lifecycle is realized on the Foundation `Lifecycle` primitive (DES-007).

### Phase 6 — Repository Protocols

Order: the repository protocols of §3.5 — `WorkspaceRepository`, `ProviderRepository`, `ConversationRepository`, `ConfigurationRepository`.

### Phase 7 — Domain Services and Policies

Order: the provider lifecycle service, and the provider selection service and policy of §3.2.

### Phase 8 — Package Verification

The full verification of the package against the completion criteria of the roadmap: every type covered by deterministic, black-box unit tests (DES-004 §5); the dependency graph limited to OmniaFoundation and acyclic; no forbidden dependency imported (no UI, networking, or persistence); the internal graph acyclic (ARC-002, ARC-007, ARC-008).

No API beyond the categories of Section 3 enters the package in these phases. Each phase ends in a state that is a valid, documented, tested increment of the public contract.

## Related Documents

- `Documentation/Product/Roadmap/DOMAIN_SPRINT_1_ROADMAP.md` — the roadmap that sequences this contract.
- `Documentation/Product/Roadmap/DOMAIN_SPRINT_2_ROADMAP.md` — the roadmap that sequences the capability extension of this revision.
- `Documentation/Design/FOUNDATION_API.md` — the parent contract of the package this package depends on.
- `Documentation/Design/API/API_DESIGN_GUIDELINES.md` — the standard every API specification follows.
- `Documentation/Design/API/IDENTIFIER_API.md`
- `Documentation/Design/API/CLOCK_API.md`
- `Documentation/Design/API/LIFECYCLE_API.md`
- `Documentation/Design/API/CANCELLATION_API.md`
- `Documentation/Architecture/02_LAYERED_ARCHITECTURE.md`
- `Documentation/Architecture/03_MODULE_MODEL.md`
- `Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md`
- `Documentation/Architecture/05_LOCAL_STORAGE_ARCHITECTURE.md`
- `Documentation/Architecture/07_MODULE_STRUCTURE.md`
- `Documentation/Architecture/08_PACKAGE_MODEL.md`
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md`
- `Documentation/Architecture/ADR/ADR-0001-architectural-style.md`
- `Documentation/Architecture/ADR/ADR-0002-dependency-direction.md`
- `Documentation/Product/PRODUCT_CHARTER.md`
- `Documentation/Product/PRODUCT_PRINCIPLES.md`
- `.ai/context/PROJECT_STATE.md`
