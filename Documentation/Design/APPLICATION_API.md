---
title: OmniaApplication Public API Contract
document_id: DES-011
version: 1.2.0
status: Ratified
owner: Founder
project: Omnia
authors:
  - Founder
reviewers:
  - Chief Architect
created: 2026-08-05
last_updated: 2026-08-09
related_documents:
  - Documentation/Product/Roadmap/APPLICATION_SPRINT_1_ROADMAP.md
  - Documentation/Product/Roadmap/MVP_V01_ROADMAP.md
  - Documentation/Design/DOMAIN_API.md
  - Documentation/Design/INFRASTRUCTURE_API.md
  - Documentation/Design/FOUNDATION_API.md
  - Documentation/Design/API/API_DESIGN_GUIDELINES.md
  - Documentation/Design/API/IDENTIFIER_API.md
  - Documentation/Architecture/01_SYSTEM_OVERVIEW.md
  - Documentation/Architecture/02_LAYERED_ARCHITECTURE.md
  - Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md
  - Documentation/Architecture/06_DEPENDENCY_INJECTION.md
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
  - application
  - api-specification
  - specification
  - engineering
---

# OmniaApplication Public API Contract

> This document is the normative engineering specification of the public API surface of the OmniaApplication package.
>
> It defines WHAT the package exposes — the contract its consumers depend on. It intentionally does NOT specify implementation.

## 1. Purpose

OmniaApplication is the Application layer package of Omnia: use cases, application services, and orchestration of user flows (ARC-009). It realizes the Application surfaces of the Application Core, Workspace, Conversation, and Settings modules (ARC-007, ARC-009). It is the package the Presentation layer depends on and the package that orchestrates the contracts declared by the Domain (ARC-002, ADR-0002).

The Application layer is where user intent becomes domain operations (ARC-001). It consumes the frozen Domain contracts — the repository protocols, the capability contracts, and the domain services — and turns them into the flows the user drives: it orchestrates cross-module workflows, defines transaction boundaries, and validates input before domain operations (ARC-009). Its purpose is not to define what Omnia is — the Domain does that — but to sequence the Domain's contracts into the flows the product needs (ARC-001 Conversation Engine, ARC-007).

This document specifies the initial public API inventory, the package responsibility boundaries, the dependency rules, the design principles, the evolution rules, and the ordered sequence in which the contract is implemented. It is derived only from the Application Sprint 1 Roadmap (`APPLICATION_SPRINT_1_ROADMAP.md`, PRD-006), the milestone #8 scope — use cases and application services for conversation, provider, and configuration flows — the frozen Domain API contract (`DOMAIN_API.md`, DES-009 v0.3.0), the frozen Infrastructure API contract (`INFRASTRUCTURE_API.md`, DES-010 v1.1.0), the Product Charter (`PRODUCT_CHARTER.md`), the Product Principles (`PRODUCT_PRINCIPLES.md`), and the approved architecture (ARC-001, ARC-002, ARC-004, ARC-006, ARC-007, ARC-008, ARC-009, ADR-0001, ADR-0002). It introduces no concept that the roadmap and the architecture do not establish.

This initial contract is frozen as **Application API Freeze v1**. From this revision, the public surface of §3 is part of the frozen contract; a change requires a specification revision, exactly as the prior API freezes do (`PROJECT_STATE.md`). It is the single source of truth for the implementation of the Application layer (PRD-006 Stage 1).

This revision (v1.1.0) extends the contract with the minimal workspace application surface of §3.8 — `WorkspaceService` and `ConversationService.createConversation(in:)` — and the provider connection endpoint surface of §3.9 — `ProviderConnectionService.updateEndpoint(_:for:)` and `endpoint(for:)` — exactly as the MVP v0.1 Roadmap sequences it (`MVP_V01_ROADMAP.md`, PRD-008, The Integration Gap and Stage 1). The extension is additive and backward-compatible (§6.3); the existing public API of the frozen Application API Freeze v1 is unchanged. The new surfaces are frozen in §3.8 and §3.9 and are the single source of truth for the implementation of the revision (PRD-008, App Contract Freeze).

This revision (v1.2.0) extends the contract with the provider connection model surface of §3.10 — `ProviderConnectionService.modelKey(for:)`, `updateModel(_:for:)`, `model(for:)`, and the `configure(_:endpoint:model:)` overload — the optional per-provider OpenAI-compatible model name (the OmniRoute combo, or any provider model name) that the app-edge selection and routing pass as the wire `model` (DES-013 §3.3, OMNIROUTE_INTEGRATION_PLAN.md). The extension is additive and backward-compatible (§6.3); the v1.1.0 `configure(_ request:)` and `remove(_:)` remain, with one documented behavior extension — `remove(_:)` also removes the recorded model key (§3.4). The new surface is frozen in §3.10 and is the single source of truth for the implementation of the revision.

The specification governs the package alone. It defines no behavior of the Foundation, Domain, Infrastructure, Presentation, or application-shell layers; those are specified by their own documents.

## 2. Package Responsibilities

### 2.1 What Belongs in OmniaApplication

OmniaApplication owns the Application-layer content of the modules it realizes (ARC-009). The following belong in the package:

- the use cases and application services for the conversation, provider connection, and configuration flows (milestone #8, PRD-006 §Scope);
- the send-message use case — the orchestration of the request and streaming-response flow of the Conversation module (ARC-001, ARC-007);
- the connection-configuration services of the Settings module (ARC-009);
- input validation before domain operations (ARC-009);
- cross-module orchestration and transaction boundaries (ARC-009);
- the application value objects and the application error taxonomy of §3.

Everything public in the package is expressible only in terms the Domain declares (ARC-002, ARC-009). The package orchestrates contracts; it never defines them (ARC-002).

### 2.2 What Must Never Belong in OmniaApplication

The following MUST NEVER enter the package (ARC-002, ARC-009, ADR-0001, ADR-0002):

- business rules and domain logic that belong to the Domain — the Application owns orchestration and validation, and the Domain's rules are never redefined here (ADR-0001, ARC-002);
- the contracts the package orchestrates — repository protocols, the capability contracts, the provider model, and the credential storage protocol are defined by the Domain, never redefined (ARC-002);
- concrete Infrastructure implementations — provider adapters, network clients, storage engines, serializers, and keychain services are injected by the Composition Root, never referenced (ARC-006);
- the user interface, presentation state, or any UI framework (ARC-002);
- networking, transport, and persistence (ARC-002);
- provider-specific code and provider APIs (ARC-004);
- the Composition Root or any dependency-injection mechanism (ARC-006);
- credential material in any form — credentials are handled by reference through the Domain credential contract and never enter logs, analytics, or request metadata (ARC-001, ARC-005);
- code with no architectural home (ARC-002).

A type that acquires a business-rule, infrastructure, provider, UI, or composition meaning is a boundary violation and is re-homed to the layer that owns that concern (DES-001 §2).

## 3. Public API Inventory

The initial public API is organized into the categories below. Each category states its purpose, its intended consumers, its stability expectations, and its ownership. The categories are the contract; the concrete declarations are defined during implementation and MUST conform to this inventory. The categories realize the application surfaces defined in the Application Sprint 1 Roadmap (`APPLICATION_SPRINT_1_ROADMAP.md` §Requirements). This inventory is the frozen surface of **Application API Freeze v1** (PRD-006 Stage 1).

The public surface of the package is the set of application services and use cases consumed by the Presentation layer (ARC-009). No upper package depends on the concrete implementations of the Domain contracts the services consume; the Composition Root binds those implementations to the Domain protocols the services depend on (ARC-006).

### 3.1 Application Value Objects

- **Purpose**: the minimal additional vocabulary the use cases need over the frozen Domain vocabulary — the value objects that combine Domain types into a use-case input (DES-004 §2, DES-009 §3.8).
- **Intended consumers**: the Presentation layer and the application services and use cases.
- **Stability expectations**: stable. Value objects are immutable once created; changes produce new values (ARC-001, ARC-003).
- **Ownership**: the module that owns each value's meaning (ARC-007): the send-message request belongs to the Conversation module; the provider-connection request belongs to the Settings module.

The category comprises:

| Type | Nature | Content |
|---|---|---|
| `SendMessageRequest` | value object | `conversation: ConversationIdentity`, `message: Message`, `userSelection: ProviderIdentity?`, `workspacePreference: ProviderIdentity?`, `capabilityPreference: ProviderIdentity?` — the conversation to drive, the user's message, and the optional selection preferences honored by the Domain selection service (DES-009 §3.2). |
| `ConfigureProviderRequest` | value object | `displayName: String`, `capabilities: ProviderCapabilities`, `limits: ProviderLimits`, `version: SemanticVersion`, `credential: Credential` — the user's declaration of a new provider connection and its credential. |

Normative statements:

- The application value objects MUST be immutable, equal by content, `Equatable` and `Sendable`, and MUST own no business logic (ARC-002, ARC-003).
- The application value objects MUST be expressed only in the existing Domain vocabulary — `ConversationIdentity`, `Message`, `ProviderIdentity`, `ProviderCapabilities`, `ProviderLimits`, `Credential`, and the version value type — and the Foundation primitives (DES-009 §3.8, DES-004 — Strong typing); raw identity, model, or version values are never used (DES-002, DES-004).
- The application MUST NOT redefine the Domain capability value objects (`StreamingUpdate`, `TextGenerationRequest`, `ConversationRequest`, `StreamingRequest`) or the Domain aggregates; the streaming view the application delivers is the Domain `StreamingUpdate` event stream (DES-009 §3.11.1, §3.11.3).
- `SendMessageRequest` carries the selection preferences as optionals; `nil` means no choice was expressed, and the Domain selection service falls through the documented priority (ARC-004, DES-009 §3.2).

### 3.2 Conversation Application Surface

- **Purpose**: create, list, select, and delete conversations, and read message history, per the Conversation module responsibilities (ARC-007) and the frozen `ConversationRepository` (DES-009 §3.5).
- **Intended consumers**: the Presentation layer (conversation screens) and the send-message use case.
- **Stability expectations**: stable. Conversations and messages are user-owned content (ARC-005).
- **Ownership**: Conversation module (Application surface, ARC-007).

The category is realized by `ConversationService`, which orchestrates the frozen `ConversationRepository` and the workspace repository for listing (DES-009 §3.5):

| Method | Meaning |
|---|---|
| `createConversation() async throws -> Conversation` | creates an empty conversation with a fresh identity and persists it (DES-002). |
| `conversation(with identity: ConversationIdentity) async throws -> Conversation?` | loads a conversation by identity — the selection operation that an active conversation is resolved from. |
| `conversations(in workspace: WorkspaceIdentity) async throws -> [Conversation]` | lists the conversations of a workspace, via the workspace's membership (ARC-007). |
| `delete(_ identity: ConversationIdentity) async throws` | removes a conversation (user ownership, ARC-005). |
| history | the full message history is owned by the aggregate and returned with it (`Conversation.history`, DES-009 §3.3); the service exposes no separate history type. |

Normative statements:

- The service MUST orchestrate the frozen repository contracts and MUST NOT invent business rules; the Conversation aggregate owns the history and streaming-state invariants (ARC-002, ADR-0001, DES-009 §3.3).
- The service MUST validate input at the boundary; invalid input is rejected with the typed application error of §3.6 before any domain operation (ARC-009).
- A conversation MUST be created with a fresh `ConversationIdentity` from the Foundation `Identifier` primitive; raw values are never used (DES-002, DES-004).
- Listing MUST enumerate the conversation identities a workspace owns and load each conversation by identity; the frozen `ConversationRepository` declares no enumeration method (DES-009 §3.5), and a global enumeration is an extension point excluded from the initial contract (§3.7).
- Repository failures MUST surface as the Domain `RepositoryError`, never wrapped (§3.6, DES-009 §3.9).
- Renaming a conversation is not expressible in the frozen Domain contract — the `Conversation` aggregate carries no name (DES-009 §3.3) — and renaming is a Workspace-module responsibility (ARC-007); it is excluded from the initial contract (§3.7).
- The active-conversation state itself is session state and belongs to the application shell, not to this surface (ARC-009 OmniaApp); the service provides the persistence operations selection operates on.

### 3.3 Send-Message Use Case

- **Purpose**: orchestrate the request and streaming-response flow of the Conversation module (ARC-007): build the capability request from the preserved conversation history, select the provider and model through the Domain selection service, deliver the streaming updates to the caller, append and persist the assembled assistant message on completion, and preserve partial content on interruption (ARC-001, DES-009 §3.3, §3.11).
- **Intended consumers**: the Presentation layer (conversation screen).
- **Stability expectations**: stable. The flow is a core conversation invariant (ARC-001).
- **Ownership**: Conversation module (Application surface, ARC-007).

The category is realized by the `SendMessageUseCase`:

| Method | Meaning |
|---|---|
| `send(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamingUpdate, Error>` | performs the streaming flow and delivers the Domain `StreamingUpdate` events incrementally. |
| `resume(_ conversation: ConversationIdentity) async throws -> AsyncThrowingStream<StreamingUpdate, Error>` | resumes the interrupted stream of a conversation — the retry/continue of an interrupted response (UX audit U7): the preserved partial content is carried forward into the reply, no user message is appended (the last prompt is already in the preserved history), and the completed reply and any second interruption preserve the content again, never discarded (ARC-001, DES-009 §3.3, §3.11.4). A conversation that is not stored, or is not marked interrupted, is rejected with the typed `ApplicationValidationError`; a failed provider selection surfaces as the Domain `CapabilityError.providerUnavailable` (§3.6, DES-009 §3.9). Additive and backward-compatible. |

Normative statements:

- The use case MUST consume only the Domain contracts — the streaming capability contract, the selection service, and the conversation repository (DES-009 §3.2, §3.5, §3.11.3) — and every collaborator MUST be injected by the Composition Root (ARC-006).
- The use case MUST append the user message to the conversation history and persist it before the stream begins; the history that reaches the provider is the persisted history (DES-009 §3.3).
- The use case MUST select the provider and model through the Domain selection service, honoring the selection priority of ARC-004; a failed selection MUST surface as the Domain `CapabilityError.providerUnavailable`, never silent degradation (DES-009 §3.2, §3.11.2).
- The use case MUST deliver the Domain `StreamingUpdate` events to the caller incrementally; the completion event carries the assembled assistant `Message` (DES-009 §3.11.1).
- On completion, the use case MUST append the assembled assistant message to the conversation and persist it — completion never loses the reply (ARC-001, DES-009 §3.3).
- On interruption, the use case MUST preserve the partial content as incomplete and MUST NOT discard it; the conversation is marked interrupted and carries the partial content forward (ARC-001, DES-009 §3.11.4).
- The resume flow MUST NOT append a user message and MUST carry the preserved partial content of the interrupted stream forward into the reply; a resume MUST reject a conversation that is not stored or is not marked interrupted, and MUST surface provider-selection failure as the Domain `CapabilityError.providerUnavailable` (ARC-001, DES-009 §3.2, §3.9, §3.11.4).
- Capability failures MUST surface as the Domain `CapabilityError`, and credential-resolution failures MUST surface as the Domain `CredentialStorageError`; neither is ever wrapped (§3.6, DES-009 §3.9).
- The flow MUST never block the caller and MUST be testable without a network; the streaming capability and the repository are injected, so tests deliver their own (ARC-001, ARC-006).
- The use case delivers exactly the events the Domain declares and invents no stream lifecycle of its own (ARC-002, DES-009 §3.11.4).

### 3.4 Provider Connection Application Surface

- **Purpose**: configure, list, and remove provider connections — the connection-configuration services of the Settings module (ARC-009) and the provider flows of the milestone (milestone #8).
- **Intended consumers**: the Presentation layer (settings screens).
- **Stability expectations**: stable. The credential boundary is a security invariant (ARC-001, ARC-004, ARC-005).
- **Ownership**: Settings module (Application surface, ARC-007).

The category is realized by `ProviderConnectionService`, which orchestrates the frozen `ProviderRepository`, the `CredentialStorageProtocol`, and the configuration repository for the credential reference (DES-009 §3.5, §3.6, §3.7):

| Method | Meaning |
|---|---|
| `configure(_ request: ConfigureProviderRequest) async throws -> ProviderConnection` | creates a provider connection with a fresh identity, persists it, stores the credential by reference, and records the reference at the provider-settings level. |
| `allProviders() async throws -> [Provider]` | lists the configured providers (DES-009 §3.5). |
| `remove(_ identity: ProviderIdentity) async throws` | removes the provider connection and its stored credential (user ownership, ARC-005). |

Normative statements:

- The service MUST orchestrate the frozen Domain contracts and MUST NOT invent business rules; the provider aggregate and its lifecycle are the Domain's (ARC-002, ADR-0001, DES-009 §3.1).
- A provider MUST be created with a fresh `ProviderIdentity` from the Foundation `Identifier` primitive; raw values are never used (DES-002, DES-004).
- The credential MUST be stored by reference through the `CredentialStorageProtocol` and MUST NEVER persist in, or enter any representation of, the connection, the repository, or the configuration beyond the pointer (ARC-001, ARC-005).
- The credential reference MUST be recorded as a configuration value at the provider-settings level, keeping the pointer separate from the data it protects (DES-009 §3.6, ARC-005).
- Provider, credential, and configuration failures MUST surface as their Domain errors — `RepositoryError`, `CredentialStorageError` — never wrapped (§3.6, DES-009 §3.9).
- Removing a provider MUST also remove its stored credential; stored data remains removable by the user (ARC-005).
- The service MUST NOT itself resolve or use the credential; resolution happens only when a request is built, in the layer that owns transport (DES-010 §3.9.3, ARC-004).

### 3.5 Configuration Application Surface

- **Purpose**: typed settings read and write with per-level resolution — the Settings module's application surface (ARC-001, ARC-007, ARC-009).
- **Intended consumers**: the Presentation layer (settings screens).
- **Stability expectations**: stable. Configuration is user-owned (ARC-005, PRODUCT_PRINCIPLES — User Ownership).
- **Ownership**: Settings module (Application surface, ARC-007).

The category is realized by `ConfigurationService`, which orchestrates the frozen `ConfigurationRepository` and the `ConfigurationResolutionPolicy` (DES-009 §3.5, §3.6):

| Method | Meaning |
|---|---|
| `store<Value: Equatable & Sendable>(_ value: Value, for key: ConfigurationKey<Value>, at level: ConfigurationLevel)` | writes a typed value at a level. |
| `value<Value: Equatable & Sendable>(for key: ConfigurationKey<Value>, at level: ConfigurationLevel) -> Value?` | reads the typed value stored at a level, or `nil` when unset. |
| `resolved<Value: Equatable & Sendable>(for key: ConfigurationKey<Value>) -> Value?` | resolves a key across levels per the resolution order of DES-009 §3.6. |
| `remove<Value: Equatable & Sendable>(_ key: ConfigurationKey<Value>, at level: ConfigurationLevel)` | removes the value stored for a key at a level. |

Normative statements:

- The service MUST orchestrate the frozen `ConfigurationRepository` and the `ConfigurationResolutionPolicy` and MUST NOT embed product decisions (DES-009 §3.6, ARC-003).
- Values MUST be typed and validated at the boundary; raw or untyped values are never stored (DES-009 §3.6, DES-004).
- Resolution MUST follow the pure, deterministic resolution order of DES-009 §3.6 — provider settings, then workspace overrides, then global defaults, then capability preferences; a higher-priority level always wins (ARC-004).
- Configuration failures MUST surface as the Domain `RepositoryError`, never wrapped (§3.6, DES-009 §3.9).
- The service MUST NOT store credentials; a stored value may hold only a `CredentialReference` pointer (ARC-004, ARC-005).

### 3.6 Typed Errors

- **Purpose**: explicit, typed failures for the operations that can fail, so errors are never silently swallowed and never leak raw values (ARC-001, DES-001 §3.9).
- **Intended consumers**: every consumer of the package; errors cross every internal boundary.
- **Stability expectations**: stable. The error surface is part of the contract (ARC-008).
- **Ownership**: the module that owns the operation's meaning (ARC-007).

The application error taxonomy is built on the Foundation error abstraction (DES-001 §3.9):

| Error | Meaning |
|---|---|
| `ApplicationValidationError` | input validation failed at the application boundary; carries a reason (ARC-009). |

Normative statements:

- Failures MUST be represented by typed errors built on the Foundation error abstraction (DES-001 §3.9); raw platform, storage, provider, or transport errors are never exposed.
- The Domain errors — `RepositoryError`, `CapabilityError`, `CredentialStorageError`, `ConversationStreamError`, and `ProviderLifecycleError` — MUST be surfaced as they are, never wrapped or redefined (DES-009 §3.9).
- Failures MUST be explicit; no application operation fails silently (ARC-001).
- No error with presentation, provider-adapter, storage-engine, or composition meaning is defined by this package; those failures belong to the Presentation, Infrastructure, and application-shell layers (ARC-004, ARC-006, ARC-009).

### 3.7 Excluded from the Initial Contract

The following are evaluated and intentionally NOT part of the initial public API of OmniaApplication (ARC-009):

- workspace application services beyond the minimal workspace surface of §3.8 — workspace select, rename, delete, and full membership management — the milestone scopes conversation, provider, and configuration flows (milestone #8, PRD-006 §Non-Goals); the minimal create, resolve, and attach surface of §3.8 exists only to make the MVP conversation flow functional (PRD-008), and the remaining workspace services are a future application sprint (ARC-007);
- conversation renaming — the frozen `Conversation` aggregate carries no name (DES-009 §3.3), and renaming is a Workspace-module responsibility (ARC-007); it becomes expressible only through a Domain specification revision, out of scope here (PRD-006 §Non-Goals);
- global conversation enumeration — the frozen `ConversationRepository` declares no all-conversations method (DES-009 §3.5); listing is realized through workspace membership (§3.2), and a global enumeration is a future Domain capability;
- non-streaming send-message — the send-message use case is the streaming flow (§3.3); a non-streaming conversation or text-generation send is a future use case over the remaining realized capabilities (DES-009 §3.1);
- the Composition Root and dependency-injection infrastructure — owned by OmniaApp (ARC-006);
- the user interface and presentation state — owned by OmniaPresentation;
- concrete Infrastructure implementations — provider adapters, network, storage, keychain — injected by the Composition Root, never referenced (ARC-006);
- the Settings presentation surface — owned by OmniaPresentation.

A category excluded here is introduced only through the evolution rules of Section 6, never by convenience (ARC-008).

### 3.8 Workspace Application Surface

- **Purpose**: create and resolve a workspace, and attach a conversation or provider to a workspace's membership — the minimal workspace edge of the MVP application (PRD-008, milestone #10). This is the v1.1.0 additive surface; it closes the integration gap recorded in the MVP v0.1 Roadmap — an application-created conversation is never attached to a workspace's membership, while the conversation list is driven by workspace membership (§3.2, PRD-008, The Integration Gap). It is the minimal slice of the workspace application services deferred by §3.7 needed to make the MVP conversation flow functional (PRD-008).
- **Intended consumers**: the Composition Root (first-run bootstrap, DES-013 §3.4) and the conversation list create flow (DES-012 §3.3 v1.1.0).
- **Stability expectations**: stable. Workspaces are user-owned data (ARC-005).
- **Ownership**: Workspace module (Application surface, ARC-007).

The category is realized by `WorkspaceService`, which orchestrates the frozen `WorkspaceRepository` and the `Workspace` aggregate (DES-009 §3.4, §3.5):

| Method | Meaning |
|---|---|
| `createWorkspace(named:) async throws -> Workspace` | creates a workspace with a fresh identity and the given name, and persists it (DES-002). |
| `workspace(with identity: WorkspaceIdentity) async throws -> Workspace?` | loads a workspace by identity, or `nil` when none is stored — the resolution operation the bootstrap and the membership operations build on. |
| `addConversation(_ identity: ConversationIdentity, to workspace: WorkspaceIdentity) async throws -> Workspace` | attaches a conversation to a workspace's membership — loads the workspace, applies the aggregate's `adding(conversation:)`, persists the new value, and returns it (DES-009 §3.4). |
| `addProvider(_ identity: ProviderIdentity, to workspace: WorkspaceIdentity) async throws -> Workspace` | attaches a provider to a workspace's membership — the same pattern over `adding(provider:)` (DES-009 §3.4). |

The v1.1.0 revision also adds one method to the §3.2 `ConversationService` surface:

| Method | Meaning |
|---|---|
| `createConversation(in workspace: WorkspaceIdentity) async throws -> Conversation` | creates an empty conversation with a fresh identity, persists it, and attaches it to the given workspace's membership as one application operation — the create-and-attach operation the conversation list create flow uses (DES-012 §3.3 v1.1.0). The v1.0.0 `createConversation()` remains unchanged. |

Normative statements:

- The services MUST orchestrate the frozen `WorkspaceRepository`, `ConversationRepository`, and the `Workspace` aggregate, and MUST NOT invent business rules — membership changes are the aggregate's value-typed `adding(conversation:)` and `adding(provider:)` methods (ARC-002, ARC-003, DES-009 §3.4).
- A workspace MUST be created with a fresh `WorkspaceIdentity` from the Foundation `Identifier` primitive; raw values are never used (DES-002, DES-004).
- An empty workspace name MUST be rejected with the typed application error of §3.6 before any domain operation (ARC-009).
- Attaching a member to a workspace that is not stored MUST surface the typed application error of §3.6 — a missing workspace is never a silent failure (ARC-001).
- `createConversation(in:)` MUST load the workspace before creating the conversation, so a missing workspace fails the whole operation before any conversation is created — create and attach are one atomic application operation (PRD-008).
- Repository failures MUST surface as the Domain `RepositoryError`, never wrapped (§3.6, DES-009 §3.9).
- The workspace selection — which workspace the application presents — is session state owned at the application edge, not by this surface (DES-013 §3.5, ARC-009 OmniaApp).

### 3.9 Provider Connection Endpoint Surface

- **Purpose**: record and resolve the OpenAI-compatible endpoint of a provider connection — the address the runtime provider adapter binding reads to construct the bound adapter (DES-013 §3.3). This is the v1.1.0 additive surface; it specifies how the endpoint — which the MVP v0.1 Roadmap requires the Composition Root to resolve at runtime — enters the system and is read back (PRD-008, Stage 1).
- **Intended consumers**: the Presentation layer (provider connection form, DES-012 §3.4 v1.1.0) and the Composition Root (adapter binding, DES-013 §3.3).
- **Stability expectations**: stable. The endpoint is connection configuration the user owns (ARC-005).
- **Ownership**: Settings module (Application surface, ARC-007).

The surface is realized by two additions to the §3.4 `ProviderConnectionService`:

| Method | Meaning |
|---|---|
| `updateEndpoint(_ endpoint: String, for identity: ProviderIdentity) async throws` | records the provider connection's OpenAI-compatible endpoint as a typed configuration value at the provider-settings level, keyed by the provider's identity. |
| `endpoint(for identity: ProviderIdentity) async throws -> String?` | returns the recorded endpoint, or `nil` when none is recorded. |

Normative statements:

- The endpoint MUST be recorded as a typed `String` configuration value at the provider-settings level under a documented key derived from the provider identity, exactly as the credential reference is (§3.4, DES-009 §3.6); raw or untyped values are never stored (DES-004).
- The endpoint MUST be validated at the boundary — a non-empty, absolute, `http` or `https` URL string — and a malformed endpoint MUST be rejected with the typed application error of §3.6 before any storage (ARC-009).
- The endpoint MUST NOT enter the `ProviderConnection` or `Provider` aggregate; the Domain provider model carries declared capabilities and metadata, never transport addresses (ARC-004, DES-009 §3.1).
- The service MUST NOT itself build a transport or an adapter; the endpoint is resolved by the Composition Root when a request is built, in the layer that owns transport (DES-010 §3.9.3, DES-013 §3.3, ARC-004).
- Configuration failures MUST surface as the Domain `RepositoryError`, never wrapped (§3.6, DES-009 §3.9).
- The endpoint is not a credential; it may be presented by the settings surface, but the credential boundary of §3.4 remains absolute (ARC-001, ARC-005).

### 3.10 Provider Connection Model Surface

- **Purpose**: record and resolve the optional per-provider OpenAI-compatible model name of a provider connection — the model (for OmniRoute, a "combo") that the app-edge offered-models closure and the runtime provider adapter binding pass as the wire `model` of every chat-completions request (DES-013 §3.3). This is the v1.2.0 additive surface; it lets a user record the provider model (the OmniRoute combo, or any OpenAI-compatible provider model name) with the connection, and closes the loop so selection and request routing use the recorded model instead of the app-edge default alone (OMNIROUTE_INTEGRATION_PLAN.md).
- **Intended consumers**: the Presentation layer (provider connection form and the Edit Model editor, DES-012 §3.4 v1.2.0) and the Composition Root (offered-models closure and adapter binding, DES-013 §3.3).
- **Stability expectations**: stable. The model is connection configuration the user owns (ARC-005).
- **Ownership**: Settings module (Application surface, ARC-007).

The surface is realized by additions to the §3.4 `ProviderConnectionService`:

| Method | Meaning |
|---|---|
| `modelKey(for identity: ProviderIdentity) -> ConfigurationKey<String>` | returns the documented provider-settings configuration key `providerModel.<identity.canonicalString>` under which the model is recorded — public because the Composition Root's runtime adapter binding reads the same key the settings surface writes (DES-004 — writers and readers never diverge). |
| `updateModel(_ model: String, for identity: ProviderIdentity) async throws` | records the provider connection's model as a typed `String` configuration value at the provider-settings level, keyed by the provider's identity. |
| `model(for identity: ProviderIdentity) async throws -> String?` | returns the recorded model, or `nil` when none is recorded. |
| `configure(_ request: ConfigureProviderRequest, endpoint: String?, model: String?) async throws -> ProviderConnection` | additive overload of the §3.4 `configure(_ request:)` — validates the endpoint and, when given, the model before any write, then records both keyed by the fresh connection identity; `nil` model records no model, so the provider falls back to the app-edge default (DES-013 §3.3). The v1.0.0 `configure(_ request:)` remains unchanged. |

Normative statements:

- The model MUST be recorded as a typed `String` configuration value at the provider-settings level under a documented key derived from the provider identity, exactly as the endpoint is (§3.9, DES-009 §3.6); raw or untyped values are never stored (DES-004).
- The model MUST be validated at the boundary — when given, a non-empty trimmed `String` — and an empty or whitespace-only model MUST be rejected with the typed application error of §3.6 before any storage (ARC-009); a `nil` model records nothing (ARC-001, DES-013 §3.3).
- The model MUST NOT enter the `ProviderConnection` or `Provider` aggregate; the Domain provider model carries declared capabilities and metadata, never transport or model-name values (ARC-004, DES-009 §3.1). The model is connection configuration, exactly like the endpoint (§3.9).
- The model MUST NOT enter the `ConfigureProviderRequest`; the credential boundary of §3.4 remains absolute, and the model is recorded separately from the request (ARC-001, ARC-005).
- The service MUST NOT itself build a transport or an adapter; the model is resolved by the Composition Root when the offered-models closure or a request is built, in the layer that owns transport (DES-010 §3.9.3, DES-013 §3.3, ARC-004).
- Configuration failures MUST surface as the Domain `RepositoryError`, never wrapped (§3.6, DES-009 §3.9).
- `remove(_:)` (§3.4) MUST also remove the recorded model key, so stored data remains removable by the user (ARC-005).

## 4. Dependency Rules

OmniaApplication occupies the Application position of the dependency graph (ARC-002, ADR-0002). Its dependency rules are absolute:

- OmniaApplication MUST depend only on OmniaDomain, whose contracts it orchestrates, and on OmniaFoundation among Omnia packages. It declares no other Omnia package dependency (ARC-009).
- OmniaApplication MAY depend on the Swift Standard Library.
- OmniaApplication MAY use OmniaFoundation primitives with no platform coupling (ARC-009): the `Identifier` primitive for identity (DES-002), and the error abstraction for the application error taxonomy (DES-001 §3.9).
- OmniaApplication MUST NOT depend on Apple platform frameworks in a way that couples the package to a single platform; the package builds and tests on the Linux build environment.
- OmniaApplication MUST NOT depend on third-party packages. Native Apple APIs are preferred (SWIFT.md, PRODUCT_CHARTER).
- OmniaApplication MUST NOT depend on any package of another layer, and MUST NOT reference Presentation, Infrastructure, or OmniaApp (ARC-002, ADR-0002).
- OmniaApplication MUST NOT reference any concrete Infrastructure implementation — provider adapters, network clients, storage engines, serializers, or keychain services. The application receives the Domain contracts it needs and never reaches for their implementations (ARC-006).
- Every dependency MUST be declared in the package manifest; hidden dependencies are forbidden (ARC-008).
- The internal type dependency graph MUST be acyclic: the services and use cases compose the Domain contracts, and nothing depends upward (ARC-002, ARC-007, ARC-009).

## 5. API Design Principles

Every public API in OmniaApplication MUST satisfy the following principles. A proposed API that fails any principle is not added (DES-004 §3).

- **Small surface area.** The public API is the smallest intentional contract that satisfies its purpose (ARC-008).
- **Stable contracts.** The public API is the contract; it changes only through the replacement process, never as a silent revision (ARC-008).
- **Explicit ownership.** Every public API has exactly one owner (ARC-007, ARC-008). Ownership is recorded in this inventory.
- **The Application orchestrates; it never defines.** Every public API consumes a Domain contract; the package defines no contract of its own (ARC-002).
- **No business rules.** Business rules belong to the Domain and Application layers only (ADR-0001); the rules the Domain owns are never redefined here.
- **Concrete implementations injected, never referenced.** The application receives its Domain dependencies from the Composition Root and never constructs or reaches for an implementation (ARC-006).
- **No UI concerns.** The package contains no user interface or presentation state (ARC-002).
- **Credential isolation.** Credentials never leave the device and never enter logs, analytics, or any representation beyond the secure storage (ARC-001, ARC-004, ARC-005).
- **Typed, explicit errors.** Failures are represented by typed errors, translated into Domain terms, and never silently swallowed (ARC-001, SWIFT.md).
- **Deterministic behavior.** Time, randomness, and external state are injected or isolated; the flows are testable without a network (ARC-001, ARC-006).
- **Precise naming.** Naming follows the architectural naming guidelines of ARC-003: the suffix of a name states the nature of the element.

## 6. Evolution Rules

### 6.1 When New APIs May Be Added

A public API is added to OmniaApplication only when:

- an existing architectural requirement recorded in the roadmap or the architecture needs it, and no existing API can express it;
- the addition is a use case or application service for an existing module — a conversation, provider, configuration, or future workspace flow — never a concept outside the roadmap (ARC-007, ARC-009);
- the addition satisfies every design principle of Section 5 and every responsibility boundary of Section 2;
- the addition is documented before it is used (PRODUCT_PRINCIPLES — Documentation First).

An API with no justified consumer is not added. A use case over a capability arrives only when the capability is realized (ARC-004, DES-009 §3.1).

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
- The dependency graph MUST remain acyclic, and OmniaApplication MUST remain dependent only on OmniaDomain and OmniaFoundation (ARC-002, ADR-0002).
- The initial contract is frozen as **Application API Freeze v1**; a change to a frozen public API requires a specification revision, and every change to this contract updates this document in the same change (DES-004 §4, PRODUCT_PRINCIPLES — Documentation First).
- A flow over a Domain capability or repository arrives only when the Domain contract provides it; a new use case never invents a Domain capability (ARC-002, DES-009 §6).

## 7. Initial Implementation Plan

Implementation follows the Application Sprint 1 Roadmap (`APPLICATION_SPRINT_1_ROADMAP.md` §Implementation Order). Each phase:

- introduces only APIs justified by this inventory and the roadmap;
- keeps the package building and its tests green at every step;
- completes with the contract documented and the API covered by tests before any cross-package consumer is added.

### Phase 1 — Application Value Objects and Errors

Order: the application value objects of §3.1 — `SendMessageRequest` and `ConfigureProviderRequest` — and the application error taxonomy of §3.6, built on the Domain vocabulary and the Foundation primitives of Section 4.

### Phase 2 — Conversation Service

Order: `ConversationService` of §3.2 — create, load (select), list by workspace membership, and delete, over the frozen `ConversationRepository` and the workspace membership (DES-009 §3.5).

### Phase 3 — Send-Message Use Case

Order: `SendMessageUseCase` of §3.3 — the streaming orchestration flow over the streaming capability contract, the selection service, and the conversation repository (DES-009 §3.2, §3.5, §3.11.3), with completion persisting the assembled assistant message and interruption preserving partial content (ARC-001).

### Phase 4 — Provider Connection Service

Order: `ProviderConnectionService` of §3.4 — configure, list, and remove provider connections over the `ProviderRepository`, the `CredentialStorageProtocol`, and the configuration repository (DES-009 §3.5, §3.6, §3.7), credentials stored by reference, never the secret (ARC-005).

### Phase 5 — Configuration Service

Order: `ConfigurationService` of §3.5 — typed settings read and write with per-level resolution over the `ConfigurationRepository` and the `ConfigurationResolutionPolicy` (DES-009 §3.5, §3.6).

### Phase 6 — Package Verification

The full verification of the package against the completion criteria of the roadmap: every type covered by deterministic, black-box unit tests (DES-004 §5); the dependency graph limited to OmniaDomain and OmniaFoundation and acyclic; no forbidden dependency imported (no UI, no presentation state, no network, no persistence, no Infrastructure or provider-adapter reference); the public surface matching the frozen §3 exactly; the flows testable without a network (ARC-001, ARC-002, ARC-006, ARC-008, ARC-009).

No API beyond the categories of Section 3 enters the package in these phases. Each phase ends in a state that is a valid, documented, tested increment of the public contract. The implementation realizes exactly the frozen surface of §3; a deviation from that surface is a defect and is resolved by correcting the implementation, never by silently changing the surface (DES-004 §1).

The v1.1.0 revision phases extend the realization:

### Phase 7 — Workspace Application Surface

Order: `WorkspaceService` of §3.8 — create, resolve, and attach over the frozen `WorkspaceRepository` and the `Workspace` aggregate's value-typed membership methods (DES-009 §3.4, §3.5), plus `ConversationService.createConversation(in:)` of §3.2 — the atomic create-and-attach the conversation list create flow needs (PRD-008, DES-012 §3.3 v1.1.0).

### Phase 8 — Provider Connection Endpoint Surface

Order: `ProviderConnectionService.updateEndpoint(_:for:)` and `endpoint(for:)` of §3.9 — the provider-settings configuration surface the Composition Root's runtime adapter binding resolves (DES-013 §3.3).

### Phase 9 — Revision Verification

The revision is verified against the same completion criteria as Phase 6: the new surfaces match §3.8 and §3.9 exactly; the v1.0.0 surface is unchanged; no forbidden dependency is imported; and the create-in-workspace flow is testable without a network (ARC-001, ARC-006).

The v1.2.0 revision phase extends the realization:

### Phase 10 — Provider Connection Model Surface

Order: `ProviderConnectionService.modelKey(for:)`, `updateModel(_:for:)`, `model(for:)`, and the `configure(_:endpoint:model:)` overload of §3.10 — the provider-settings configuration surface the Composition Root's offered-models closure and runtime adapter binding resolve (DES-013 §3.3), plus the `remove(_:)` model-key cleanup of §3.4. Verified against the completion criteria of Phase 6: the new surface matches §3.10 exactly; the v1.0.0 and v1.1.0 surfaces are unchanged; no forbidden dependency is imported; and the flows are testable without a network (ARC-001, ARC-006).

## Related Documents

- `Documentation/Product/Roadmap/APPLICATION_SPRINT_1_ROADMAP.md` — the roadmap that sequences this contract.
- `Documentation/Product/Roadmap/MVP_V01_ROADMAP.md` — the MVP roadmap that sequences the v1.1.0 revision surfaces.
- `Documentation/Design/DOMAIN_API.md` — the frozen Domain contract this package orchestrates.
- `Documentation/Design/INFRASTRUCTURE_API.md` — the frozen Infrastructure contract whose implementations the Composition Root injects.
- `Documentation/Design/FOUNDATION_API.md` — the parent contract of the package this package depends on.
- `Documentation/Design/API/API_DESIGN_GUIDELINES.md` — the standard every API specification follows.
- `Documentation/Design/API/IDENTIFIER_API.md` — the identity primitive the application value objects build on.
- `Documentation/Architecture/01_SYSTEM_OVERVIEW.md`
- `Documentation/Architecture/02_LAYERED_ARCHITECTURE.md`
- `Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md`
- `Documentation/Architecture/06_DEPENDENCY_INJECTION.md`
- `Documentation/Architecture/07_MODULE_STRUCTURE.md`
- `Documentation/Architecture/08_PACKAGE_MODEL.md`
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md`
- `Documentation/Architecture/ADR/ADR-0001-architectural-style.md`
- `Documentation/Architecture/ADR/ADR-0002-dependency-direction.md`
- `Documentation/Product/PRODUCT_CHARTER.md`
- `Documentation/Product/PRODUCT_PRINCIPLES.md`
- `.ai/context/PROJECT_STATE.md`
