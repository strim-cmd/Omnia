---
title: OmniaPresentation Public API Contract
document_id: DES-012
version: 1.1.0
status: Ratified
owner: Founder
project: Omnia
authors:
  - Founder
reviewers:
  - Chief Architect
created: 2026-08-05
last_updated: 2026-08-06
related_documents:
  - Documentation/Product/Roadmap/PRESENTATION_SPRINT_1_ROADMAP.md
  - Documentation/Product/Roadmap/MVP_V01_ROADMAP.md
  - Documentation/Design/APPLICATION_API.md
  - Documentation/Design/DOMAIN_API.md
  - Documentation/Design/INFRASTRUCTURE_API.md
  - Documentation/Design/FOUNDATION_API.md
  - Documentation/Design/API/API_DESIGN_GUIDELINES.md
  - Documentation/Architecture/01_SYSTEM_OVERVIEW.md
  - Documentation/Architecture/02_LAYERED_ARCHITECTURE.md
  - Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md
  - Documentation/Architecture/05_LOCAL_STORAGE_ARCHITECTURE.md
  - Documentation/Architecture/06_DEPENDENCY_INJECTION.md
  - Documentation/Architecture/07_MODULE_STRUCTURE.md
  - Documentation/Architecture/08_PACKAGE_MODEL.md
  - Documentation/Architecture/09_PACKAGE_STRUCTURE.md
  - Documentation/Architecture/ADR/ADR-0001-architectural-style.md
  - Documentation/Architecture/ADR/ADR-0002-dependency-direction.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - Documentation/Product/PRODUCT_PRINCIPLES.md
  - .ai/standards/UI.md
  - .ai/context/PROJECT_STATE.md
supersedes: []
tags:
  - design
  - presentation
  - api-specification
  - specification
  - engineering
---

# OmniaPresentation Public API Contract

> This document is the normative engineering specification of the public API surface of the OmniaPresentation package.
>
> It defines WHAT the package exposes — the contract its consumers depend on. It intentionally does NOT specify implementation.

## 1. Purpose

OmniaPresentation is the Presentation layer package of Omnia: the user interface — screens, views, and interactions (`ARC-009`). It realizes the Presentation surfaces of the Navigation, Conversation, and Settings modules (`ARC-007`, `ARC-009`). It is the package that renders the application services of the frozen `DES-011` v1.0.0 and translates user intent into use-case invocations (`ARC-002`, `ADR-0001`).

The Presentation layer renders state and owns presentation-only concerns: layout, animation, accessibility, and localization (`ARC-002`). It receives the application services it renders and owns its own presentation objects (`ARC-006`); the style is SwiftUI, the Observation framework, and Navigation, with no business logic (`ADR-0001`). Its purpose is not to orchestrate flows — the Application does that — but to present the ready-to-render state the services produce and to hand user intent back as use-case invocations (`ARC-001`, `ARC-007`).

This document specifies the initial public API inventory, the package responsibility boundaries, the dependency rules, the design principles, the evolution rules, and the ordered sequence in which the contract is implemented. It is derived only from the Presentation Sprint 1 Roadmap (`PRESENTATION_SPRINT_1_ROADMAP.md`, PRD-007), the MVP v0.1 Roadmap (`MVP_V01_ROADMAP.md`, PRD-008) for the v1.1.0 revision surfaces, the milestone #9 scope — the navigation structure and the conversation and settings presentation surfaces, rendering the verified application services and the streaming send-message flow — the frozen Application API contract (`APPLICATION_API.md`, DES-011 v1.1.0), the frozen Domain API contract (`DOMAIN_API.md`, DES-009 v0.3.0), the Product Charter (`PRODUCT_CHARTER.md`), the Product Principles (`PRODUCT_PRINCIPLES.md`), the UI standard (`.ai/standards/UI.md`), and the approved architecture (ARC-001, ARC-002, ARC-004, ARC-005, ARC-006, ARC-007, ARC-008, ARC-009, ADR-0001, ADR-0002). It introduces no concept that the roadmap and the architecture do not establish.

This initial contract is frozen as **Presentation API Freeze v1**. From this revision, the public surface of §3 is part of the frozen contract; a change requires a specification revision, exactly as the prior API freezes do (`PROJECT_STATE.md`). It is the single source of truth for the implementation of the Presentation layer (PRD-007 Stage 1), including the resolved Markdown rendering and code highlighting mechanism (§3.3).

This revision (v1.1.0) extends the contract with the conversation list create-in-workspace flow of §3.3 and the provider connection form's endpoint collection of §3.4 — exactly as the MVP v0.1 Roadmap sequences it (`MVP_V01_ROADMAP.md`, PRD-008, The Integration Gap and Stage 1). The extension is additive and backward-compatible (§6.3); the existing public API of the frozen Presentation API Freeze v1 is unchanged. The new surfaces are frozen in §3.3 and §3.4 and are the single source of truth for the implementation of the revision (PRD-008, App Contract Freeze).

The specification governs the package alone. It defines no behavior of the Foundation, Domain, Application, Infrastructure, or application-shell layers; those are specified by their own documents.

## 2. Package Responsibilities

### 2.1 What Belongs in OmniaPresentation

OmniaPresentation owns the Presentation-layer content of the modules it realizes (`ARC-009`). The following belong in the package:

- the navigation structure and presentation flow of the Navigation module — the one-to-one module of this package (`ARC-007`);
- the conversation presentation surface — the conversation list and the conversation screen presenting the streaming send-message flow (the Conversation module, `ARC-009`);
- the settings presentation surface — provider connections and configuration (the Settings module, `ARC-009`);
- the presentation value types, presentation state, and the navigation model that the surfaces render;
- the seam through which the application services of `DES-011` are delivered to the surfaces (`ARC-006`);
- layout, animation, accessibility, and localization of the surfaces (`.ai/standards/UI.md`).

The package renders the frozen `DES-011` application surface; it defines no contract and owns no business rule (`ARC-002`, `ADR-0001`).

### 2.2 What Must Never Belong in OmniaPresentation

The following MUST NEVER enter the package (`ARC-002`, `ARC-009`, ADR-0001, ADR-0002):

- business rules and domain logic — they belong to the Domain and Application layers; the Presentation renders state and translates intent and never redefines the rules (ADR-0001);
- networking, transport, persistence, and credential operations — they are delivered through the application services and never performed here (ARC-002, ADR-0002);
- concrete Infrastructure implementations — provider adapters, network clients, storage engines, serializers, and keychain services are injected by the Composition Root, never referenced (`ARC-006`);
- the contracts the services orchestrate — repository protocols, capability contracts, and the provider model are the Domain's, never redefined or consumed directly (ARC-002, ARC-009);
- provider-specific code and provider APIs — the interface never changes per provider (`PRODUCT_PRINCIPLES` — Provider Independence, `ARC-004`);
- the Composition Root, the application shell, the entry point, the lifecycle, or any dependency-injection mechanism — owned by OmniaApp (`ARC-006`, `ARC-009`);
- credential material in any form — the secret is never rendered, stored, or logged; only the configured state is presented (`ARC-001`, `ARC-005`);
- the workspace presentation surface — workspace application services are a future application sprint (`DES-011` §3.7);
- third-party packages — native Apple APIs are preferred (`.ai/standards/SWIFT.md`, `PRODUCT_CHARTER`);
- code with no architectural home (`ARC-002`).

A type that acquires a business-rule, infrastructure, provider, composition, or credential meaning is a boundary violation and is re-homed to the layer that owns that concern (`DES-001` §2).

## 3. Public API Inventory

The initial public API is organized into the categories below. Each category states its purpose, its intended consumers, its stability expectations, and its ownership. The categories are the contract; the concrete declarations are defined during implementation and MUST conform to this inventory. The categories realize the presentation surfaces defined in the Presentation Sprint 1 Roadmap (`PRESENTATION_SPRINT_1_ROADMAP.md` §Requirements). This inventory is the frozen surface of **Presentation API Freeze v1** (PRD-007 Stage 1).

The public surface of the package is the set of presentation surfaces consumed by OmniaApp at the application edge (`ARC-009`): the navigation structure, the conversation surface, the settings surface, and the value types and state those surfaces expose. The surfaces consume the `DES-011` application services; the Composition Root supplies those services and their collaborators through the package seam of §3.6 (`ARC-006`).

### 3.1 Presentation Value Types

- **Purpose**: the minimal additional vocabulary the surfaces need over the frozen Application and Domain vocabulary — the ready-to-render values that combine the application service results into the state the views present (`DES-004` §2, `DES-011` §3.1).
- **Intended consumers**: the presentation surfaces and the view layer of the package.
- **Stability expectations**: stable. Value types are immutable once created; changes produce new values (`ARC-001`, `ARC-003`).
- **Ownership**: the module that owns each value's meaning (`ARC-007`): the conversation values belong to the Conversation module; the provider-connection value belongs to the Settings module.

The category comprises:

| Type | Nature | Content |
|---|---|---|
| `ConversationListItem` | value object | `identity: ConversationIdentity`, `displayTitle: String`, `displayPreview: String?` — the identity and the display content of a conversation row, derived from the conversation's content (the frozen `ConversationIdentity` and `Conversation` vocabulary of `DES-009` §3.3). |
| `MessagePresentation` | value object | `role: MessageRole`, `content: MarkdownContent?` — the presentation form of a Domain `Message` for the conversation screen, distinguishing user, assistant, and system content (the frozen `Message` and `MessageRole` vocabulary of `DES-009` §3.3). |
| `MarkdownContent` | value object | the platform-independent markdown content model of a message: the ordered sequence of text segments and code-block segments (§3.3.1). |
| `ProviderConnectionListItem` | value object | `identity: ProviderIdentity`, `displayName: String`, `state: ProviderState` — the identity, the declared display name, and the lifecycle state of a configured provider connection row (the frozen `ProviderIdentity`, `ProviderMetadata.displayName`, and `ProviderState` vocabulary of `DES-009` §3.1–§3.2). |

Normative statements:

- The presentation value types MUST be immutable, equal by content, `Equatable` and `Sendable`, and MUST own no business logic (`ARC-002`, `ARC-003`).
- The presentation value types MUST be expressed only in the frozen Application and Domain vocabulary — the `ConversationIdentity`, `Conversation`, `Message`, `MessageRole`, `ProviderIdentity`, `ProviderMetadata`, `ProviderState`, and `Provider` vocabulary — and the Foundation primitives (`DES-009`, `DES-011`, `DES-004` — Strong typing); raw identities or values are never used (`DES-002`, `DES-004`).
- The Presentation MUST NOT redefine the Domain aggregates, messages, capabilities, or value objects; a presentation value type carries derived display content and never replaces the Domain type it presents (`ARC-002`, `DES-011` §3.1).
- Deriving display content (a list-row title and preview from a conversation, a provider row from a connection) is presentation logic — the rendering of state — never business logic (`ARC-002`, `ADR-0001`).
- The value types MUST NEVER carry credentials; the credential boundary of `ARC-005` holds at every presentation type (`ARC-001`, `ARC-005`).
- `MarkdownContent` is the single content model for assistant messages; its segmentation is deterministic and testable without a platform (§3.7).

### 3.2 Presentation State

- **Purpose**: the ready-to-render state of the presentation surfaces, owned by the Presentation layer (`ARC-009`) and composed from the application services it renders (`ARC-006`).
- **Intended consumers**: the view layer of the package; OmniaApp composes the surfaces that own the state (§3.6).
- **Stability expectations**: stable. Presentation state is session state, never a Domain or Application concept (`DES-011` §3.7); the state types are immutable value types.
- **Ownership**: the module that owns each surface (`ARC-007`): conversation state belongs to the Conversation module; settings state belongs to the Settings module; navigation state belongs to the Navigation module.

The category comprises the state models of the surfaces of §3.3, §3.4, and §3.5:

| State | Surface | Content |
|---|---|---|
| `ConversationListState` | conversation list | the ordered `ConversationListItem`s of the list, and the empty and error conditions the list presents (create, select, delete over `ConversationService`, `DES-011` §3.2). |
| `ConversationScreenState` | conversation screen | the `MessagePresentation`s of the active conversation's history, the user input draft, and the rendered streaming condition — active, complete, or interrupted (§3.3.1, `DES-011` §3.3). |
| `SettingsState` | settings | the `ProviderConnectionListItem`s of the configured connections, the configuration values the settings surface presents, and the compose and error conditions (`DES-011` §3.4, §3.5). |
| `NavigationState` | navigation | the current route of the navigation structure — which surface the shell presents and the presentation flow that produced it (§3.5). |

Normative statements:

- The presentation state MUST be owned by the Presentation layer and MUST be composed only from the application services it renders (`ARC-006`, `ARC-009`); no state is global (`ARC-007`).
- The presentation state MUST be session state and MUST NEVER become a Domain or Application concept (`DES-011` §3.7); the surfaces expose the state the application edge composes.
- The state models MUST be immutable value types and MUST own no business logic (`ARC-002`).
- The rendered streaming condition MUST mirror the Domain stream's active, complete, and interrupted conditions without redefining them (`DES-009` §3.11.4, `DES-011` §3.3): the partial content on interruption is preserved and presented, never discarded (`ARC-001`).
- The state MUST NOT hold credentials, raw secrets, or provider-specific detail (`ARC-001`, `ARC-004`, `ARC-005`).

### 3.3 Conversation Presentation Surface

- **Purpose**: the conversation list and the conversation screen — the Presentation surface of the Conversation module (`ARC-007`): create, select, and delete conversations over `ConversationService` (`DES-011` §3.2), and present the streaming send-message flow over `SendMessageUseCase` (`DES-011` §3.3).
- **Intended consumers**: OmniaApp at the application edge; the view layer renders the surface's state.
- **Stability expectations**: stable. Conversations and messages are user-owned content (`ARC-005`); the streaming flow is a core conversation invariant (`ARC-001`).
- **Ownership**: Conversation module (Presentation surface, `ARC-007`).

The category comprises:

| Element | Meaning |
|---|---|
| Conversation list | presents `ConversationListState`: the conversations of the list over `ConversationService` — create (the create-in-workspace flow, below, `DES-011` §3.8), select (a conversation by identity via `conversation(with:)`), and delete (via `delete(_:)`, user ownership, `ARC-005`). |
| Create-in-workspace flow (v1.1.0) | translates the user's create action on the list into a create-in-workspace invocation — `ConversationListSurface.create(in: the presented workspace)` over `ConversationService.createConversation(in:)` (`DES-011` §3.8) — so every new conversation belongs to the workspace the list presents and appears in the membership-driven list (`DES-011` §3.2, PRD-008). The v1.0.0 `create()` surface method remains part of the surface but is not what the list renders (`DES-011` §3.2, §3.8). |
| Conversation screen | presents `ConversationScreenState`: the history of the active conversation, the user input draft, and the streaming flow over `SendMessageUseCase` — the Domain `StreamingUpdate` events rendered incrementally without blocking the interface, the assembled assistant message on completion, and the preserved partial content on interruption, never discarded (`DES-011` §3.3, `ARC-001`). |
| Send-message intent | translates the user's send action and the selection preferences into the frozen `SendMessageRequest` (`DES-011` §3.1, §3.3) and invokes the streaming use case. |

Normative statements:

- The surface MUST consume only the frozen `DES-011` conversation surface — `ConversationService` and `SendMessageUseCase` — and MUST NOT invent business rules or new use cases (`ARC-002`, `DES-011` §3.2, §3.3).
- The list surface MUST render the conversations over `ConversationService`; selecting a conversation presents it by identity, and deleting a conversation is the user's removal of their own content (`ARC-005`).
- The list surface MUST receive the workspace identity it presents from the application edge — the workspace selection is session state owned there, not by this surface (`DES-011` §3.8, `ARC-009` OmniaApp) — and MUST create each new conversation in that workspace and list its membership (`createConversation(in:)` and `conversations(in:)`, `DES-011` §3.2, §3.8); the list and the create action MUST never diverge on the workspace (PRD-008).
- The screen surface MUST render the Domain `StreamingUpdate` events incrementally as they arrive and MUST NOT block the interface during streaming (`ARC-001`, `DES-011` §3.3); the completed message is rendered from the completion event's assembled assistant message, and interruption renders the preserved partial content as incomplete — never discarded (`ARC-001`, `DES-009` §3.11.4).
- The send-message intent MUST compose the frozen `SendMessageRequest` from the user input, the selected conversation, and the optional selection preferences, and MUST NOT perform the flow itself (`DES-011` §3.1).
- The failures the services surface — `ApplicationValidationError`, and the Domain `RepositoryError`, `CapabilityError`, and `CredentialStorageError` — MUST be presented as they are, never wrapped or redefined (`DES-011` §3.6, `DES-009` §3.9); no failure is silent (`ARC-001`).
- The active-conversation selection is session state owned at the application edge (`DES-011` §3.2); this surface presents the conversation it is given and exposes the operations and state the application edge composes.

#### 3.3.1 Markdown Rendering and Code Highlighting

Assistant message content is Markdown and is rendered with code highlighting — an in-scope product requirement (`PRODUCT_CHARTER` — Product Goals, In Scope). The mechanism is bounded by two non-goals that are product invariants: **no third-party packages** (native Apple APIs are preferred, `PRODUCT_CHARTER`, `.ai/standards/SWIFT.md`) and **no provider-specific UI** (`PRODUCT_PRINCIPLES` — Provider Independence). The mechanism recorded here is the single source of truth for implementation (`PRESENTATION_SPRINT_1_ROADMAP.md` §Clarification); a deviation from it is a defect.

The mechanism:

- **Content model.** The platform-independent surface carries the assistant message content as the `MarkdownContent` value type of §3.1: the ordered sequence of prose text segments and fenced code-block segments, with the code-block's content and whitespace preserved. Segmenting fenced code blocks is deterministic presentation logic, testable on the Linux build environment (§3.7).
- **Rendering.** The Apple-platform view layer renders the Markdown using native Apple APIs only — Foundation `AttributedString` Markdown parsing and native SwiftUI/TextKit rendering for inline styling (emphasis, code spans, links) and block presentation (paragraphs, lists, fenced code blocks). No third-party Markdown renderer is added.
- **Code highlighting.** Code blocks are presented as distinct code-block elements — monospaced text, a distinct background, preserved whitespace and wrapping — without language-aware syntax coloring. Language-aware syntax coloring requires a third-party library, which the no-third-party-packages non-goal excludes; it is not part of Presentation Sprint 1 and is introduced only through a specification revision or ADR that amends the non-goal.
- **View-layer boundary.** The parsing and rendering execute in the Apple-platform view layer, isolated behind platform availability; the platform-independent surface never imports the view layer (§3.7).

Normative statements:

- The rendering MUST use native Apple APIs only; no third-party Markdown renderer or syntax-highlighting library enters the package (`PRODUCT_CHARTER`, `PRESENTATION_SPRINT_1_ROADMAP.md` §Clarification).
- Code blocks MUST be presented with monospaced text, a distinct background, and preserved whitespace; language-aware syntax coloring MUST NOT be implemented in this sprint.
- The `MarkdownContent` segmentation MUST be deterministic and platform-independent; the rendering MUST be confined to the Apple-platform view layer.
- The rendering MUST NOT couple the interface to any provider; Markdown rendering is provider-agnostic (`PRODUCT_PRINCIPLES` — Provider Independence).

### 3.4 Settings Presentation Surface

- **Purpose**: provider connections and configuration — the Presentation surface of the Settings module (`ARC-007`): configure, list, and remove provider connections over `ProviderConnectionService` (`DES-011` §3.4), and present configuration over `ConfigurationService` (`DES-011` §3.5).
- **Intended consumers**: OmniaApp at the application edge; the view layer renders the surface's state.
- **Stability expectations**: stable. The credential boundary is a security invariant (`ARC-001`, `ARC-004`, `ARC-005`); configuration is user-owned (`ARC-005`).
- **Ownership**: Settings module (Presentation surface, `ARC-007`).

The category comprises:

| Element | Meaning |
|---|---|
| Provider connections | presents `SettingsState`: the configured connections over `ProviderConnectionService` — configure (compose the frozen `ConfigureProviderRequest`, `DES-011` §3.1, §3.4), list (`allProviders`, deterministic order), and remove (`remove(_:)`, user ownership, `ARC-005`) — with the credential boundary honored: the secret is never rendered, stored, or logged; only the configured state is presented (`ARC-001`, `ARC-005`). |
| Configuration | presents the typed configuration values over `ConfigurationService` — store, read, resolve, and remove typed values at the documented levels (`DES-011` §3.5). |
| Connection-form intent | translates the user's declaration of a new provider connection into the frozen `ConfigureProviderRequest` — display name, capabilities, limits, version, and the credential entered by the user — and hands it to `ProviderConnectionService` (`DES-011` §3.1, §3.4). |
| Endpoint collection (v1.1.0) | collects the provider's OpenAI-compatible endpoint with the connection declaration and records it through `ProviderConnectionService.updateEndpoint(_:for:)` (`DES-011` §3.9) — the address the runtime provider adapter binding resolves (`DES-013` §3.3, PRD-008). The endpoint is never a credential and is presented by this surface, but the credential boundary of the connection-form intent remains absolute (`ARC-001`, `ARC-005`). |

Normative statements:

- The surface MUST consume only the frozen `DES-011` settings surface — `ProviderConnectionService` and `ConfigurationService` — and MUST NOT invent business rules or new use cases (`ARC-002`, `DES-011` §3.4, §3.5).
- The credential boundary is absolute: the entered secret passes into the frozen `ConfigureProviderRequest`, whose storage by reference is the service's concern (`DES-011` §3.4, `ARC-005`); the secret MUST NEVER be rendered, stored, persisted, or logged by the package (`ARC-001`, `ARC-005`).
- The surface MUST present the generic connection state — identity, display name, capabilities, and lifecycle state — and MUST NEVER change the interface per provider or expose provider-specific detail (`PRODUCT_PRINCIPLES` — Provider Independence, `ARC-004`). Live availability is discovered and reported by the Infrastructure layer, never by this surface (`ARC-004` Capability Discovery).
- The configuration values MUST be typed through the frozen configuration vocabulary — `ConfigurationKey` and `ConfigurationLevel` (`DES-009` §3.6, `DES-011` §3.5); raw or untyped values are never presented.
- The endpoint MUST be recorded through the frozen `ProviderConnectionService` endpoint surface (`DES-011` §3.9) and MUST NOT enter the connection declaration or any Domain aggregate; the transport address is connection configuration, never provider model (`DES-011` §3.9, `ARC-004`). A malformed endpoint is rejected by the service's boundary validation and presented as the typed `ApplicationValidationError` (`DES-011` §3.6).
- The failures the services surface — `ApplicationValidationError`, and the Domain `RepositoryError` and `CredentialStorageError` — MUST be presented as they are, never wrapped or redefined (`DES-011` §3.6, `DES-009` §3.9); no failure is silent (`ARC-001`).

### 3.5 Navigation Presentation Surface

- **Purpose**: the navigation structure and presentation flow — the Presentation surface of the Navigation module, the one-to-one module of this package (`ARC-007`, `ARC-009`): the shell that hosts and routes between the conversation and settings surfaces.
- **Intended consumers**: OmniaApp at the application edge; the view layer renders the surface's state.
- **Stability expectations**: stable. The flow between the surfaces is the shell the application edge composes.
- **Ownership**: Navigation module (Presentation surface, `ARC-007`).

The category comprises:

| Element | Meaning |
|---|---|
| Navigation model | the `NavigationState` of §3.2: the set of destinations — the conversation list, the conversation screen, and the settings surface — and the current route. |
| Presentation flow | the flow between the destinations per platform conventions: the conversation list opens a conversation and reaches the settings surface (`ADR-0001`, `ARC-001` Workspace). |
| Platform navigation | the platform-native navigation container — Navigation on iOS, iPadOS, and macOS (`ADR-0001`) — hosting the surfaces and matching platform conventions (`.ai/standards/UI.md`). |

Normative statements:

- The navigation surface MUST own the navigation structure and presentation flow and MUST contain no business logic (`ARC-002`, `ARC-007`).
- The routes of the navigation model MUST be value types; the current route is presentation state (`ARC-007`).
- The navigation MUST follow platform conventions for iOS, iPadOS, and macOS and MUST feel native on every platform (`ARC-001`, `ADR-0001`, `PRODUCT_CHARTER`).
- The navigation surface MUST reach the conversation and settings surfaces through their presentation surfaces and MUST NOT reference the Application services it does not host (§3.6).
- The navigation structure is realized with Navigation and the Observation framework, following `ADR-0001`.

### 3.6 The Composition Seam

- **Purpose**: the seam through which the application services of `DES-011` are delivered to the presentation surfaces (`ARC-006`) — the package boundary the Composition Root composes.
- **Intended consumers**: OmniaApp (the future Composition Root, `ARC-006`, `ARC-009`).
- **Stability expectations**: stable. The seam is part of the public contract (`ARC-008`).
- **Ownership**: the module that owns each surface (`ARC-007`); the seam belongs to the package's public surface.

The seam is the public initializer of every surface:

| Surface | Delivered collaborators |
|---|---|
| Conversation list | `ConversationService` (`DES-011` §3.2) — including the v1.1.0 create-in-workspace operation and the workspace-membership list it renders; the workspace identity the list presents is session state supplied by the application edge alongside the service (`DES-011` §3.8). |
| Conversation screen | `SendMessageUseCase` (`DES-011` §3.3). |
| Settings | `ProviderConnectionService` and `ConfigurationService` (`DES-011` §3.4, §3.5) — including the v1.1.0 endpoint surface of `ProviderConnectionService` (`DES-011` §3.9). |
| Navigation | the conversation and settings surfaces; it hosts them, it does not construct their services. |

Normative statements:

- The presentation surfaces MUST receive their application-service collaborators through their public initializers — dependencies are delivered, never acquired (`ARC-006`).
- The Composition Root MUST construct the `DES-011` services — which themselves receive the Domain contract implementations — and inject them into the surfaces; the package MUST NEVER reference, construct, or reach for a concrete Infrastructure implementation (`ARC-006`, `ARC-009`).
- The seam MUST NOT expose the Domain contracts the services orchestrate; the surfaces consume the services' public API only (`ARC-009`).
- The package MUST NOT contain a Composition Root, a dependency-injection mechanism, or any global or acquired-state lookup (`ARC-006`).

### 3.7 Build and Verification Boundary

- **Purpose**: the boundary between the platform-independent presentation logic and the Apple-platform SwiftUI view layer, so the testable surface runs on the standard build environment and the native layer is isolated (`PRESENTATION_SPRINT_1_ROADMAP.md` §Build and Verification Boundary).
- **Intended consumers**: the implementation and the verification pipeline.
- **Stability expectations**: stable. The boundary is part of the contract.
- **Ownership**: the package (`ARC-009`).

The boundary has two sides:

| Surface | Position | Verification |
|---|---|---|
| Platform-independent presentation logic | the value types of §3.1, the presentation state of §3.2, the navigation model of §3.5, and the content derivation of §3.3.1 (including `MarkdownContent` segmentation). | builds and is tested on the Linux build environment; deterministic, black-box tests of the public surface (`DES-004` §5). |
| Apple-platform view layer | SwiftUI views, Observation, navigation containers, and the `AttributedString`/TextKit Markdown rendering of §3.3.1. | isolated behind platform availability via conditional compilation; not exercised by the Linux test environment; verified by review against `.ai/standards/UI.md`. |

Normative statements:

- The platform-independent presentation logic MUST build and test on the Linux build environment; the SwiftUI view layer MUST be isolated behind platform availability, following the conditional-compilation precedent of OmniaInfrastructure (Keychain, URLSession) (`PRESENTATION_SPRINT_1_ROADMAP.md` §Build and Verification Boundary).
- The view layer MUST NOT be exercised by the Linux test environment; its verification is review against the UI standard and the Apple Human Interface Guidelines.
- The two sides MUST communicate through the public value and state types; the view layer MUST NOT reach into the internals of the platform-independent surface (`ARC-007`, `DES-004` §5).

### 3.8 Excluded from the Initial Contract

The following are evaluated and intentionally NOT part of the initial public API of OmniaPresentation (`ARC-009`):

- the workspace presentation surface — workspace application services beyond the minimal surface the list's create-in-workspace flow and the bootstrap need are a future application sprint (`DES-011` §3.7, §3.8); full workspace screens arrive only when the remaining workspace services do (`ARC-007`);
- the Composition Root, the application shell, the entry point, and the application lifecycle — owned by OmniaApp (`ARC-006`, `ARC-009`);
- business logic and business rules — they belong to the Domain and Application layers (ADR-0001);
- provider-specific UI — the interface never changes per provider (`PRODUCT_PRINCIPLES` — Provider Independence);
- language-aware syntax coloring for code blocks — it requires a third-party library, excluded by the no-third-party-packages non-goal; it is introduced only through a specification revision or ADR (`PRESENTATION_SPRINT_1_ROADMAP.md` §Clarification);
- third-party packages — native Apple APIs are preferred (`PRODUCT_CHARTER`, `.ai/standards/SWIFT.md`);
- any new package — the package set is fixed at six (`ARC-009`);
- any dependency-injection framework — explicitly excluded by the architecture (`ARC-006`);
- changes to the frozen `DES-001`..`DES-011` contracts — `DES-012` is the only new contract of the sprint (`PRESENTATION_SPRINT_1_ROADMAP.md` §Non-Goals).

A category excluded here is introduced only through the evolution rules of Section 6, never by convenience (`ARC-008`).

## 4. Dependency Rules

OmniaPresentation occupies the Presentation position of the dependency graph (`ARC-002`, ADR-0002). Its dependency rules are absolute:

- OmniaPresentation MUST depend only on OmniaApplication, whose services it renders, and on OmniaFoundation among Omnia packages. It declares no other Omnia package dependency (`ARC-009`).
- The Domain vocabulary the surfaces hold — conversations, messages, provider connections, and the streaming events — is the vocabulary exposed through the OmniaApplication public interface; OmniaPresentation MUST NOT declare an OmniaDomain package dependency, which would be a skip-level edge (`ARC-002`, `ARC-009`).
- OmniaPresentation MAY depend on the Swift Standard Library.
- OmniaPresentation MAY use OmniaFoundation primitives with no platform coupling (`ARC-009`): the `Identifier` primitive for identity (`DES-002`) and the error abstraction where a presentation value needs a typed status.
- OmniaPresentation MUST NOT depend on Apple platform frameworks in a way that couples the package to a single platform: the platform-independent presentation logic builds and tests on the Linux build environment, and the SwiftUI view layer is isolated behind platform availability (§3.7).
- OmniaPresentation MUST NOT depend on third-party packages. Native Apple APIs are preferred (`.ai/standards/SWIFT.md`, `PRODUCT_CHARTER`).
- OmniaPresentation MUST NOT depend on any package of another layer, and MUST NOT reference Domain, Infrastructure, or OmniaApp (`ARC-002`, ADR-0002).
- OmniaPresentation MUST NOT reference any concrete Infrastructure implementation — provider adapters, network clients, storage engines, serializers, or keychain services. The surfaces receive the `DES-011` services they need and never reach for their implementations (`ARC-006`).
- Every dependency MUST be declared in the package manifest; hidden dependencies are forbidden (`ARC-008`).
- The internal type dependency graph MUST be acyclic: the surfaces compose the application services, and nothing depends upward (`ARC-002`, `ARC-007`, `ARC-009`).

## 5. API Design Principles

Every public API in OmniaPresentation MUST satisfy the following principles. A proposed API that fails any principle is not added (`DES-004` §3).

- **Small surface area.** The public API is the smallest intentional contract that satisfies its purpose (`ARC-008`).
- **Stable contracts.** The public API is the contract; it changes only through the replacement process, never as a silent revision (`ARC-008`).
- **Explicit ownership.** Every public API has exactly one owner (`ARC-007`, `ARC-008`). Ownership is recorded in this inventory.
- **The Presentation renders state; it never defines.** Every public surface consumes an application service; the package defines no contract and owns no business rule (`ARC-002`, ADR-0001).
- **No business rules.** Business rules belong to the Domain and Application layers only (ADR-0001); the rules the Domain and Application own are never redefined here.
- **Concrete implementations injected, never referenced.** The surfaces receive their `DES-011` collaborators from the Composition Root and never construct or reach for an implementation (`ARC-006`).
- **No UI logic outside the view layer.** The platform-independent surface carries value types, state, and content derivation; the SwiftUI view layer owns layout, animation, accessibility, and localization (§3.7, `.ai/standards/UI.md`).
- **Native experience.** SwiftUI views with the Observation framework and Navigation (`ADR-0001`); native SwiftUI components preferred over custom ones, following the Apple Human Interface Guidelines (`.ai/standards/UI.md`, `PRODUCT_CHARTER`); accessibility (VoiceOver, Dynamic Type, keyboard navigation where appropriate, high contrast, reduced motion) and localization are product requirements (`ARC-001`, `UI.md`); user-visible strings are localized and never hardcoded in view code (`UI.md`).
- **Credential isolation.** The secret is never rendered, stored, or logged; only the configured state is presented (`ARC-001`, `ARC-004`, `ARC-005`).
- **No provider-specific UI.** The interface never changes per provider (`PRODUCT_PRINCIPLES` — Provider Independence).
- **Typed, explicit errors.** Failures are represented by the typed errors the services surface and are never silently swallowed (`ARC-001`, `.ai/standards/SWIFT.md`); the presentation presents them as they are, never wrapped.
- **Deterministic behavior.** Content derivation and presentation state are deterministic and testable without a platform (`ARC-001`, §3.7).
- **Precise naming.** Naming follows the architectural naming guidelines of `ARC-003`: the suffix of a name states the nature of the element.

## 6. Evolution Rules

### 6.1 When New APIs May Be Added

A public API is added to OmniaPresentation only when:

- an existing architectural requirement recorded in the roadmap or the architecture needs it, and no existing API can express it;
- the addition is a presentation surface or screen for an existing module — a conversation, settings, navigation, or future workspace surface — never a concept outside the roadmap (`ARC-007`, `ARC-009`);
- the addition satisfies every design principle of Section 5 and every responsibility boundary of Section 2;
- the addition is documented before it is used (`PRODUCT_PRINCIPLES` — Documentation First).

An API with no justified consumer is not added. A screen over an application service arrives only when the service is realized (`DES-011`, `ARC-004`).

### 6.2 When APIs May Be Removed

A public API is removed only through the defined deprecation lifecycle (`ARC-008`):

1. **Announce** — the API is marked deprecated; no new consumers are added.
2. **Migrate** — existing consumers move to the replacement.
3. **Remove** — the API is removed when no consumer remains.

A significant removal is recorded in the package's version history and, when architectural, as an ADR (`ARC-007`).

### 6.3 Compatibility Expectations

- The public API follows Semantic Versioning (`ARC-008`, `DOCUMENTATION.md`).
- A revision MUST preserve the contract; a breaking change is a replacement, never a revision (`ARC-008`).
- Additions MUST be backward-compatible: new APIs are additive and MUST NOT alter the behavior of existing APIs.
- The dependency graph MUST remain acyclic, and OmniaPresentation MUST remain dependent only on OmniaApplication and OmniaFoundation (`ARC-002`, ADR-0002).
- The initial contract is frozen as **Presentation API Freeze v1**; a change to a frozen public API requires a specification revision, and every change to this contract updates this document in the same change (`DES-004` §4, `PRODUCT_PRINCIPLES` — Documentation First).
- A surface over an application service arrives only when the service provides it; a new screen never invents an application capability (`ARC-002`, `DES-011` §6).
- A Markdown rendering or code-highlighting change that requires language-aware syntax coloring is a change to the no-third-party-packages non-goal and is introduced only through a specification revision or ADR (`PRESENTATION_SPRINT_1_ROADMAP.md` §Clarification).

## 7. Initial Implementation Plan

Implementation follows the Presentation Sprint 1 Roadmap (`PRESENTATION_SPRINT_1_ROADMAP.md` §Implementation Order). Each phase:

- introduces only APIs justified by this inventory and the roadmap;
- keeps the package building and its tests green at every step;
- completes with the contract documented and the API covered by tests before any cross-package consumer is added.

### Phase 1 — Presentation Value Types and State

Order: the presentation value types of §3.1 — `ConversationListItem`, `MessagePresentation`, `MarkdownContent`, and `ProviderConnectionListItem` — and the presentation state of §3.2 — `ConversationListState`, `ConversationScreenState`, `SettingsState`, and `NavigationState` — built on the frozen `DES-011` surface and the Foundation primitives of Section 4. `MarkdownContent` segmentation is deterministic and tested on the Linux build environment (§3.3.1, §3.7).

### Phase 2 — Conversation Presentation Surface

Order: the conversation list and the conversation screen of §3.3 — create (the v1.1.0 create-in-workspace flow, `createConversation(in:)`), select, and delete over `ConversationService`, and the streaming send-message flow over `SendMessageUseCase` with the Domain `StreamingUpdate` events rendered incrementally, the assembled assistant message on completion, and the preserved partial content on interruption (`DES-011` §3.2, §3.3, §3.8); the `MarkdownContent` segmentation is realized and tested; the Apple-platform view layer renders Markdown per §3.3.1.

### Phase 3 — Settings Presentation Surface

Order: the settings surface of §3.4 — provider connections (configure, list, remove over `ProviderConnectionService`, credential boundary honored, never rendered, and the v1.1.0 endpoint collection through `updateEndpoint(_:for:)`, `DES-011` §3.9) and configuration over `ConfigurationService` (`DES-011` §3.4, §3.5).

### Phase 4 — Navigation Structure and Presentation Flow

Order: the navigation structure of §3.5 — the navigation model, the presentation flow between the conversation and settings surfaces, and the platform-native navigation container (`ADR-0001`) — hosting the surfaces of Phases 2 and 3 (the Navigation module, `ARC-007`).

### Phase 5 — Package Verification

The full verification of the package against the completion criteria of the roadmap: every type covered by deterministic, black-box unit tests on the Linux build environment (`DES-004` §5); the dependency graph limited to OmniaApplication and OmniaFoundation and acyclic; no forbidden dependency imported (no business logic, no networking, no persistence, no provider code, no Infrastructure or Domain reference); the public surface matching the frozen §3 exactly; the platform-independent presentation logic testable on the Linux build environment and the SwiftUI view layer isolated behind platform availability; the view layer verified by review against `.ai/standards/UI.md` (`ARC-002`, `ARC-004`, `ARC-006`, `ARC-009`, ADR-0001).

No API beyond the categories of Section 3 enters the package in these phases. Each phase ends in a state that is a valid, documented, tested increment of the public contract. The implementation realizes exactly the frozen surface of §3; a deviation from that surface is a defect and is resolved by correcting the implementation, never by silently changing the surface (`DES-004` §1).

The v1.1.0 revision phases extend the realization:

### Phase 6 — Create-in-Workspace Flow

Order: the conversation list's create-in-workspace flow of §3.3 — the list creates each new conversation in the workspace the application edge supplies (`ConversationService.createConversation(in:)`, `DES-011` §3.8) and renders the membership-driven list; the workspace identity is received, never selected by the surface (`DES-011` §3.8, `ARC-009` OmniaApp).

### Phase 7 — Endpoint Collection

Order: the provider connection form's endpoint collection of §3.4 — the form records the endpoint through `ProviderConnectionService.updateEndpoint(_:for:)` (`DES-011` §3.9), presenting boundary validation failures as the typed `ApplicationValidationError`.

### Phase 8 — Revision Verification

The revision is verified against the same completion criteria as Phase 5: the new flows match §3.3 and §3.4 exactly; the v1.0.0 surface is unchanged; the platform-independent flow logic is testable on the Linux build environment; and no forbidden dependency is imported (`ARC-002`, `ARC-006`, `ARC-009`).

## Related Documents

- `Documentation/Product/Roadmap/PRESENTATION_SPRINT_1_ROADMAP.md` — the roadmap that sequences this contract.
- `Documentation/Product/Roadmap/MVP_V01_ROADMAP.md` — the MVP roadmap that sequences the v1.1.0 revision flows.
- `Documentation/Design/APPLICATION_API.md` — the frozen Application contract this package renders.
- `Documentation/Design/DOMAIN_API.md` — the frozen Domain contract whose vocabulary this package presents.
- `Documentation/Design/INFRASTRUCTURE_API.md` — the frozen Infrastructure contract whose implementations the Composition Root injects.
- `Documentation/Design/FOUNDATION_API.md` — the parent contract of the package this package depends on.
- `Documentation/Design/API/API_DESIGN_GUIDELINES.md` — the standard every API specification follows.
- `Documentation/Architecture/01_SYSTEM_OVERVIEW.md`
- `Documentation/Architecture/02_LAYERED_ARCHITECTURE.md`
- `Documentation/Architecture/04_AI_PROVIDER_ARCHITECTURE.md`
- `Documentation/Architecture/05_LOCAL_STORAGE_ARCHITECTURE.md`
- `Documentation/Architecture/06_DEPENDENCY_INJECTION.md`
- `Documentation/Architecture/07_MODULE_STRUCTURE.md`
- `Documentation/Architecture/08_PACKAGE_MODEL.md`
- `Documentation/Architecture/09_PACKAGE_STRUCTURE.md`
- `Documentation/Architecture/ADR/ADR-0001-architectural-style.md`
- `Documentation/Architecture/ADR/ADR-0002-dependency-direction.md`
- `Documentation/Product/PRODUCT_CHARTER.md`
- `Documentation/Product/PRODUCT_PRINCIPLES.md`
- `.ai/standards/UI.md`
- `.ai/context/PROJECT_STATE.md`
