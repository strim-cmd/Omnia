---
title: OmniaApp Public API Contract
document_id: DES-013
version: 1.0.0
status: Ratified
owner: Founder
project: Omnia
authors:
  - Founder
reviewers:
  - Chief Architect
created: 2026-08-06
last_updated: 2026-08-06
related_documents:
  - Documentation/Product/Roadmap/MVP_V01_ROADMAP.md
  - Documentation/Design/APPLICATION_API.md
  - Documentation/Design/PRESENTATION_API.md
  - Documentation/Design/DOMAIN_API.md
  - Documentation/Design/INFRASTRUCTURE_API.md
  - Documentation/Design/FOUNDATION_API.md
  - Documentation/Design/API/API_DESIGN_GUIDELINES.md
  - Documentation/Design/API/IDENTIFIER_API.md
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
  - .ai/context/PROJECT_STATE.md
supersedes: []
tags:
  - design
  - app-shell
  - composition
  - api-specification
  - specification
  - engineering
---

# OmniaApp Public API Contract

> This document is the normative engineering specification of the public API surface of the OmniaApp package.
>
> It defines WHAT the package exposes — the contract its consumers depend on. It intentionally does NOT specify implementation.

## 1. Purpose

OmniaApp is the application edge of Omnia — the sixth and final package the architecture always anticipated (`ARC-009`). It realizes the application edge of the Application Core module (`ARC-007`, `ARC-009`): the Composition Root, the app shell, the entry point, and the lifecycle. It is not a layer; it is the assembly point at which the layers are composed (`ARC-006`). OmniaApp owns the Composition Root — the only place where abstractions are bound to implementations — owns the application and session state, and owns the storage layout and the first-run bootstrap that make the frozen layers runnable as one application (`ARC-006`, `ARC-009`, `PRD-008`).

The Composition Root assembles the complete object graph: the concrete Infrastructure implementations — the four file repositories, the `SecureCredentialStorage` with the platform-appropriate backend, and the OpenAI-compatible provider adapter — are injected into the application services of `DES-011`, which are injected into the presentation surfaces of `DES-012`. The app shell and entry point launch on macOS, run the first-run bootstrap — resolving or creating the default workspace — and host `RootView` with the resolved workspace and configuration keys, so the milestone definition is proven end to end: the user configures a provider connection, creates a conversation, sends a message, watches the streaming response, and sees all state persist across launches (`PRD-008`, `ARC-001`, `ARC-005`).

This document specifies the initial public API inventory, the package responsibility boundaries, the dependency rules, the design principles, the evolution rules, and the ordered sequence in which the contract is implemented. It is derived only from the MVP v0.1 Roadmap (`MVP_V01_ROADMAP.md`, PRD-008), the frozen Application API contract (`APPLICATION_API.md`, DES-011 v1.1.0), the frozen Presentation API contract (`PRESENTATION_API.md`, DES-012 v1.1.0), the frozen Domain and Infrastructure contracts (`DOMAIN_API.md`, DES-009; `INFRASTRUCTURE_API.md`, DES-010), the Product Charter (`PRODUCT_CHARTER.md`), the Product Principles (`PRODUCT_PRINCIPLES.md`), and the approved architecture (ARC-001, ARC-002, ARC-004, ARC-005, ARC-006, ARC-007, ARC-008, ARC-009, ADR-0001, ADR-0002). It introduces no concept that the roadmap and the architecture do not establish.

This initial contract is frozen as **App Contract Freeze v1**, ratified together with the additive revisions DES-011 v1.1.0 and DES-012 v1.1.0 (PRD-008, App Contract Freeze). From this revision, the public surface of §3 is part of the frozen contract; a change requires a specification revision, exactly as the prior API freezes do (`PROJECT_STATE.md`). It is the single source of truth for the implementation of the application edge (PRD-008 Stage 1).

The specification governs the package alone. It defines no behavior of the Foundation, Domain, Application, Infrastructure, or Presentation layers; those are specified by their own documents.

## 2. Package Responsibilities

### 2.1 What Belongs in OmniaApp

OmniaApp owns the application-edge content of the Application Core module (`ARC-009`). The following belong in the package:

- the Composition Root — the single assembly point of the complete object graph, and the only place concrete Infrastructure implementations are referenced (`ARC-006`, `ARC-009`);
- the storage layout — the directory scheme of the four file repositories, rooted in the platform Application Support directory (`ARC-005`);
- the runtime provider adapter binding — the mechanism that maps a configured provider connection to a bound adapter (`PRD-008`);
- the first-run bootstrap — resolving or creating the default workspace (`PRD-008`);
- the app shell — owning the application and session state at the application edge, including the current workspace identity (`ARC-009`, `DES-011` §3.8);
- the executable entry point and the application lifecycle (`ARC-009`);
- the package manifest declaring the dependency on every other package — the deliberate exception to fan-in that makes the whole graph visible at the root (`ARC-009`, `ARC-007`).

Everything public in the package is composition or lifecycle. The package binds the frozen contracts of the five lower packages; it never defines a contract of its own (`ARC-002`).

### 2.2 What Must Never Belong in OmniaApp

The following MUST NEVER enter the package (`ARC-002`, `ARC-006`, `ARC-009`, ADR-0001, ADR-0002):

- business rules, domain logic, and product behavior — they belong to the Domain and Application layers; the Composition Root assembles and launches, it never decides product behavior (ADR-0001, `ARC-009`);
- orchestration beyond construction — flow sequencing is the Application layer's (`ARC-002`, `ARC-009`);
- the contracts the Composition Root binds — repository protocols, the capability contracts, the provider model, and the credential storage protocol are defined by the Domain, never redefined (ARC-002);
- the application services and use cases — orchestration and validation belong to OmniaApplication (`ARC-009`);
- the user interface, presentation surfaces, and presentation state — hosted, never defined (`ARC-009`);
- networking, transport, persistence, and credential operations performed by the shell — the Composition Root assembles the implementations that perform them; it never performs them itself (ARC-002, ARC-006);
- provider-specific code and provider APIs (ARC-004);
- any dependency-injection framework — the Composition Root is hand-written (`ARC-006`, PRD-008 §Non-Goals);
- third-party packages — native Apple APIs are preferred (`PRODUCT_CHARTER`, `.ai/standards/SWIFT.md`);
- code with no architectural home (ARC-002).

A type that acquires a business-rule, orchestration, contract, UI, infrastructure, or provider meaning is a boundary violation and is re-homed to the layer that owns that concern (DES-001 §2).

## 3. Public API Inventory

The public API is the composition contract and the executable entry point (`ARC-009` §OmniaApp). OmniaApp has no consumers below it — no package depends on OmniaApp (`ARC-006`) — so its "public surface" is the shape the platform launcher and the verification pipeline observe: the categories below. Each category states its purpose, its intended consumers, its stability expectations, and its ownership. The categories are the contract; the concrete declarations are defined during implementation and MUST conform to this inventory. This inventory is the frozen surface of **App Contract Freeze v1** (PRD-008 Stage 1).

The categories realize the application-edge surfaces defined in the MVP v0.1 Roadmap (`MVP_V01_ROADMAP.md` §The Application Surface).

### 3.1 Composition Root

- **Purpose**: the single assembly point that constructs the object graph — the concrete Infrastructure implementations (the four file repositories, the `SecureCredentialStorage` with the platform-appropriate backend, and the OpenAI-compatible provider adapter) injected into the application services of `DES-011`, which are injected into the presentation surfaces of `DES-012` (`ARC-006`, `ARC-009`). The Composition Root assembles; it owns no business logic and no orchestration beyond construction (ARC-002).
- **Intended consumers**: the executable entry point; the verification pipeline.
- **Stability expectations**: stable. The wiring is the composition contract (ARC-008).
- **Ownership**: Application Core module (Application edge, ARC-007, ARC-009).

The composition contract is the ordered construction of the graph:

1. **Storage root** — the application-support storage root of §3.2.
2. **Repositories** — `FileWorkspaceRepository(directory:)`, `FileConversationRepository(directory:)`, `FileProviderRepository(directory:)`, and `FileConfigurationRepository(directory:)`, one directory each (DES-010 §3.1).
3. **Credential storage** — `SecureCredentialStorage()`, selecting the platform-appropriate backend (DES-010 §3.4).
4. **Application services** — `WorkspaceService`, `ConversationService`, `ProviderConnectionService`, `ConfigurationService`, and `SendMessageUseCase` of DES-011 §3.2–§3.5, §3.8, §3.9, over the injected Domain contracts.
5. **Runtime provider adapter binding** — the bound `OpenAICompatibleProviderAdapter` of §3.3, delivered as the capability contract the send-message use case consumes (DES-011 §3.3).
6. **Presentation surfaces** — the conversation list, conversation screen, and settings surfaces over their frozen seams (DES-012 §3.6), composed into the navigation surface (DES-012 §3.5).
7. **Root view** — `RootView(surface:workspace:configurationKeys:)` with the resolved workspace and the settings surface's configuration keys (DES-012 §3.5).

Normative statements:

- The Composition Root MUST be the only place concrete Infrastructure implementations are referenced; no other package references them (`ARC-006`).
- The Composition Root MUST construct, wire, and deliver; it MUST NOT perform business logic, networking, persistence, or credential operations (`ARC-002`, `ARC-006`, `ARC-009`).
- The Composition Root MUST deliver the presentation surfaces the frozen seams of DES-012 §3.6 declare; the shell MUST NEVER mention an Infrastructure implementation (`ARC-006`).
- The services MUST be the concrete implementations the frozen DES-011 declares; the Composition Root binds, it never defines (ARC-002).
- The Composition Root MUST be hand-written; no dependency-injection framework enters the package (`ARC-006`, PRD-008 §Non-Goals).
- The graph MUST be complete and acyclic; a service or surface is delivered exactly the collaborators its frozen contract declares (ARC-002, ARC-008).

### 3.2 Storage Layout

- **Purpose**: the persistent directory scheme — one directory per repository, rooted in the platform Application Support directory (`ARC-005`) — so documents are addressed by identity key alone and different aggregates never share a namespace (DES-010 §3.1).
- **Intended consumers**: the Composition Root (construction); the verification pipeline.
- **Stability expectations**: stable. Stored data must remain stable across launches (`ARC-005`).
- **Ownership**: Application Core module (Application edge, ARC-009).

The layout:

- **Root** — the platform Application Support directory, derived from Foundation (`FileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)`), joined with a stable application-named subdirectory. The root is derived once, at composition, and delivered to the repositories as their parent directory.
- **One directory per repository** under the root:

| Repository | Directory |
|---|---|
| `FileWorkspaceRepository` | `Workspaces/` |
| `FileConversationRepository` | `Conversations/` |
| `FileProviderRepository` | `Providers/` |
| `FileConfigurationRepository` | `Configuration/` |

- **Lazy creation** — each directory is created lazily on the first save (DES-010 §3.2), never eagerly at launch.
- **Credential isolation** — the credential storage backend holds secrets outside the file layout — Keychain on Apple platforms, in-memory on Linux (`DES-010` §3.4) — and never in these directories (`ARC-005`).

Normative statements:

- Each repository MUST be rooted in its own directory under the storage root; documents are addressed by identity key alone, and different aggregates MUST NOT share a namespace (DES-010 §3.1).
- The storage root MUST be derived deterministically from the platform Application Support directory and a stable application subdirectory; it MUST NOT depend on the current working directory or on transient values.
- Directories MUST be created lazily on the first save, never eagerly at launch (DES-010 §3.2).
- The credential storage MUST NOT reside in the file layout; on Apple platforms it is the Keychain, on Linux it is in-memory (DES-010 §3.4, `ARC-005`).
- Stored data MUST remain exportable and removable by the user (`ARC-005`).

### 3.3 Runtime Provider Adapter Binding

- **Purpose**: the mechanism by which a configured provider connection is mapped to a bound `OpenAICompatibleProviderAdapter` — its endpoint and stored credential reference — and delivered to the send-message use case as the capability contract it consumes (`PRD-008`, DES-010 §3.6, §3.9, DES-011 §3.3).
- **Intended consumers**: the Composition Root; the send-message use case.
- **Stability expectations**: stable. The binding is the integration the milestone proves (PRD-008).
- **Ownership**: Application Core module (Application edge, ARC-009).

The mechanism:

- The Composition Root reads, per configured provider connection, two typed configuration values at the provider-settings level (DES-009 §3.6): the stored credential reference — recorded by `ProviderConnectionService.configure(_:)` (DES-011 §3.4) — and the stored endpoint — recorded by `ProviderConnectionService.updateEndpoint(_:for:)` (DES-011 §3.9).
- Each value is addressed by a documented, stable key derived from the provider identity's canonical string — a `ConfigurationKey<CredentialReference>` and a `ConfigurationKey<String>` at the provider-settings level — so the writer (the settings surface) and the reader (the Composition Root) never diverge (DES-011 §3.9, DES-004).
- For the provider the user's selection resolves (DES-009 §3.2, DES-011 §3.3), the Composition Root constructs `OpenAICompatibleProviderAdapter(endpoint:credential:credentialStorage:)` — the endpoint parsed from the recorded URL string, the credential reference as stored — and delivers the adapter as the `StreamingContract`/`TextGenerationContract` the send-message use case consumes (DES-010 §3.6, DES-009 §3.11.3, DES-011 §3.3).
- The adapter is constructed through its public initializer over the default transport (DES-010 §3.6); a configured connection with no recorded endpoint or no stored credential reference is not bindable and MUST surface the provider as unavailable through the Domain discovery channel — never a launch failure, never silent (DES-009 §3.2, DES-010 §3.9.3).

Normative statements:

- The binding MUST resolve the endpoint and the credential reference from the provider-settings configuration — the exact values the settings surfaces record (DES-011 §3.4, §3.9) — never from untyped, raw, or global values (DES-009 §3.6, DES-004).
- The adapter MUST be constructed through its public initializer over the default transport (DES-010 §3.6); the endpoint is the recorded URL string parsed at the boundary, and the credential is the stored reference — the raw secret is resolved only when a request is built, never in composition (DES-010 §3.9.3, `ARC-005`).
- The delivered capability MUST be the Domain `StreamingContract`/`TextGenerationContract` the send-message use case declares (DES-011 §3.3); the Composition Root binds the contract, it never redefines it (ARC-002).
- A provider whose binding inputs are incomplete MUST be reported unavailable through the Domain discovery channel — never a launch failure, never silent (DES-009 §3.2, DES-010 §3.9.3).
- The adapter MUST be the only path from the application to a provider transport; no other layer builds or owns a transport (`ARC-004`, `ARC-006`).

### 3.4 First-Run Bootstrap

- **Purpose**: resolve-or-create the default workspace on launch — a single default workspace is bootstrapped, and workspace management UI remains excluded (`PRD-008`, DES-011 §3.7).
- **Intended consumers**: the app shell at launch.
- **Stability expectations**: stable. The default workspace is the root of the MVP data model.
- **Ownership**: Application Core module (Application edge, ARC-009).

The mechanism:

- The bootstrap resolves the default workspace identity from an application-owned configuration value at the global-defaults level (DES-009 §3.6), keyed by a documented, stable constant of the app edge. The value is the default workspace's canonical identity string (DES-002, DES-011 §3.8).
- When the value is absent — first launch — the bootstrap creates a workspace through `WorkspaceService.createWorkspace(named:)` (DES-011 §3.8), records its canonical identity under the bootstrap key, and resolves it.
- When the value is present but no stored workspace matches — deleted or lost data — the bootstrap creates a fresh default workspace, re-records its identity, and resolves it: launch never fails on an absent workspace.
- The resolved default workspace identity is delivered to the app shell as session state and to `RootView` as its workspace (DES-012 §3.3, §3.5; DES-011 §3.8).
- First-run is silent: no onboarding surface (`PRD-008` §Non-Goals).

Normative statements:

- The bootstrap MUST resolve the default workspace identity deterministically through an application-owned configuration value at the global-defaults level, recorded as the canonical identity string — a well-known identity is never fabricated at launch (DES-011 §3.8, DES-004).
- The bootstrap MUST create the default workspace through `WorkspaceService.createWorkspace(named:)` — never by constructing the aggregate — when none is recorded or none resolves (DES-011 §3.8).
- The bootstrap MUST be idempotent across launches: the same workspace is resolved until the user removes it (`ARC-005`).
- The bootstrap MUST run on the Linux build environment with the platform-independent Composition Root (§3.6); the default workspace name is a documented constant of the app edge (`PRD-008`).
- Launch MUST NOT present onboarding or any workspace management UI (`PRD-008` §Non-Goals).

### 3.5 App Shell, Entry Point, and Lifecycle

- **Purpose**: the executable entry point launches on macOS, runs the first-run bootstrap, builds the navigation surface over the presentation surfaces, and hosts `RootView` with the resolved workspace and configuration keys (`PRD-008`, DES-012 §3.5). The shell owns session state — the current workspace identity — at the application edge (DES-011 §3.8, `ARC-009`).
- **Intended consumers**: the platform launcher; the user.
- **Stability expectations**: stable. The launch sequence is the application lifecycle.
- **Ownership**: Application Core module (Application edge, ARC-009).

The launch sequence:

1. **Launch** — the SwiftUI `@main` App on macOS (ADR-0001).
2. **Compose** — the Composition Root of §3.1 constructs the object graph.
3. **Bootstrap** — the first-run bootstrap of §3.4 resolves or creates the default workspace.
4. **Build the surface** — the navigation surface of DES-012 §3.5 is assembled over the presentation surfaces delivered by the Composition Root (DES-012 §3.6).
5. **Host** — `RootView(surface:workspace:configurationKeys:)` presents the shell with the resolved workspace and the settings surface's configuration keys (DES-012 §3.5).
6. **Lifecycle** — the shell owns the streaming-task lifecycle and the navigation-route state (DES-012 §3.2, §3.5); termination persists everything the services already persisted — the shell adds no persistence of its own (ARC-005).

Normative statements:

- The executable entry point MUST be isolated behind platform availability; the Composition Root and the bootstrap logic MUST be platform-independent and testable on the Linux build environment (§3.6, PRD-008).
- The shell MUST own session state at the application edge — the current workspace identity and the current route — and MUST NOT re-select a workspace or re-derive state the services own (DES-011 §3.8, DES-012 §3.2, ARC-009).
- The shell MUST host the surfaces through their frozen seams (DES-012 §3.6) and MUST NOT reference an Infrastructure implementation (ARC-006).
- The shell MUST drive the streaming flow through the conversation surface's send seam, honoring cancellation and preserving partial content on interruption (DES-012 §3.3, DES-011 §3.3, ARC-001).
- The lifecycle MUST NOT add persistence beyond the services'; every operation persists through the services and repositories (ARC-005).

### 3.6 Build and Verification Boundary

- **Purpose**: the boundary between the platform-independent Composition Root and bootstrap logic — which build and test on the Linux build environment — and the Apple-platform executable entry point — isolated behind platform availability — following the OmniaInfrastructure platform-backend precedent (PRD-008, DES-010 §3.4).
- **Intended consumers**: the implementation and the verification pipeline.
- **Stability expectations**: stable. The boundary is part of the contract.
- **Ownership**: the package (ARC-009).

The boundary has two sides:

| Surface | Position | Verification |
|---|---|---|
| Composition Root and bootstrap logic | platform-independent; constructs the graph and resolves the default workspace over the frozen services | builds and is tested on the Linux build environment; deterministic, black-box tests of the public surface (DES-004 §5) |
| Executable entry point | the SwiftUI `@main` App; Apple-platform only | isolated behind platform availability via conditional compilation; not exercised by the Linux test environment; verified by review against `.ai/standards/UI.md` |

Normative statements:

- The Composition Root and bootstrap logic MUST build and test on the Linux build environment, following the conditional-compilation precedent of OmniaInfrastructure (Keychain, URLSession) (PRD-008, DES-010 §3.4).
- The executable entry point MUST be isolated behind platform availability and MUST NOT be exercised by the Linux test environment.
- The two sides MUST communicate through the composition contract and the frozen DES-012 seams; the entry point MUST NOT reach into the internals of the Composition Root (ARC-007, DES-004 §5).

### 3.7 Excluded from the Initial Contract

The following are evaluated and intentionally NOT part of the initial public API of OmniaApp (ARC-009):

- workspace management UI — a single default workspace is bootstrapped; workspace create, list, select, rename, delete, and membership screens remain excluded (DES-011 §3.7, DES-012 §3.8);
- onboarding — first-run is a silent bootstrap of the default workspace (PRD-008 §Non-Goals);
- platform packaging and distribution — signing, notarization, sandbox entitlements, and the app bundle are outside this contract;
- multi-window support and the document-based lifecycle — the MVP is single-window (PRD-008);
- background synchronization, iCloud, and cloud features;
- third-party dependencies — native Apple APIs are preferred (PRODUCT_CHARTER, `.ai/standards/SWIFT.md`);
- any dependency-injection framework — the Composition Root is hand-written (ARC-006);
- new packages — the package set is fixed at six (ARC-009);
- changes to the frozen DES-001..DES-012 contracts — DES-013 is the final contract of the freeze; the additive revisions DES-011 v1.1.0 and DES-012 v1.1.0 are the surfaces this contract composes, and a further change requires another specification revision (PRD-008, PROJECT_STATE.md).

A category excluded here is introduced only through the evolution rules of Section 6, never by convenience (ARC-008).

## 4. Dependency Rules

OmniaApp occupies the application-edge position of the dependency graph (ARC-002, ARC-009, ADR-0002). Its dependency rules are absolute:

- OmniaApp MUST depend on every other package — OmniaPresentation, OmniaApplication, OmniaInfrastructure, OmniaDomain, and OmniaFoundation (ARC-009). This is the deliberate exception to fan-in that lets the Composition Root see the whole graph (ARC-007).
- OmniaApp MUST be the only package whose outgoing edges reach every other package; the Composition Root is the only place concrete Infrastructure implementations are referenced (ARC-006).
- No package MAY depend on OmniaApp — the shell is the top; depending on it would make every package depend on the composition of everything (ARC-006, ARC-009).
- OmniaApp MAY depend on the Swift Standard Library and the Apple platform frameworks the executable entry point requires — SwiftUI and Foundation — but Apple-only code MUST be isolated behind platform availability (§3.6).
- OmniaApp MUST NOT depend on third-party packages. Native Apple APIs are preferred (PRODUCT_CHARTER, `.ai/standards/SWIFT.md`).
- The dependency graph MUST contain no cycle (ARC-002, ARC-007).
- Every dependency MUST be declared in the package manifest; hidden dependencies are forbidden (ARC-008).

## 5. API Design Principles

Every public API in OmniaApp MUST satisfy the following principles. A proposed API that fails any principle is not added (DES-004 §3).

- **Small surface area.** The public API is the smallest intentional assembly and launch contract that satisfies its purpose (ARC-008).
- **Stable contracts.** The public API is the contract; it changes only through the replacement process, never as a silent revision (ARC-008).
- **Explicit ownership.** Every public API has exactly one owner (ARC-007, ARC-008). Ownership is recorded in this inventory.
- **Assembled, never defined.** The Composition Root binds the frozen contracts of the five lower packages; the package defines no contract of its own (ARC-002).
- **No business rules.** Business rules belong to the Domain and Application layers only (ADR-0001); the shell launches and composes, it never decides product behavior.
- **The only Infrastructure reference point.** Concrete Infrastructure implementations are referenced here and nowhere else; the shell never reaches for an implementation (ARC-006).
- **No UI.** The package contains no user interface; it hosts the surfaces the Presentation layer defines (ARC-009).
- **Credential isolation.** Credentials never leave the device and never enter logs, analytics, or any representation beyond the secure storage; the shell handles only references (ARC-001, ARC-004, ARC-005).
- **Deterministic behavior.** The bootstrap and composition are deterministic and testable without a network (ARC-001, ARC-006).
- **Precise naming.** Naming follows the architectural naming guidelines of ARC-003: the suffix of a name states the nature of the element.

## 6. Evolution Rules

### 6.1 When New APIs May Be Added

A public API is added to OmniaApp only when:

- an existing architectural requirement recorded in the roadmap or the architecture needs it, and no existing API can express it;
- the addition is composition or lifecycle for an existing package — the wiring of a new repository, service, surface, or provider at the root — never a concept outside the roadmap (ARC-006, ARC-009);
- the addition satisfies every design principle of Section 5 and every responsibility boundary of Section 2;
- the addition is documented before it is used (PRODUCT_PRINCIPLES — Documentation First).

An API with no justified consumer is not added. Composition for a capability arrives only when the capability is realized (ARC-004, DES-009 §3.1).

### 6.2 When APIs May Be Removed

A public API is removed only through the defined deprecation lifecycle (ARC-008):

1. **Announce** — the API is marked deprecated; no new consumers are added.
2. **Migrate** — existing consumers move to the replacement.
3. **Remove** — the API is removed when no consumer remains.

As the top package with no consumers, a removal is a revision of the composition contract, recorded in the package's version history and, when architectural, as an ADR (ARC-007).

### 6.3 Compatibility Expectations

- The public API follows Semantic Versioning (ARC-008, DOCUMENTATION.md).
- A revision MUST preserve the contract; a breaking change is a replacement, never a revision (ARC-008).
- Additions MUST be backward-compatible: new APIs are additive and MUST NOT alter the behavior of existing APIs.
- The dependency graph MUST remain acyclic, and OmniaApp MUST remain the only package whose outgoing edges reach every other package (ARC-006, ARC-009).
- The initial contract is frozen as **App Contract Freeze v1**, ratified together with DES-011 v1.1.0 and DES-012 v1.1.0; a change to a frozen public API requires a specification revision, and every change to this contract updates this document in the same change (DES-004 §4, PRODUCT_PRINCIPLES — Documentation First).
- Composition of a Domain capability or repository arrives only when the Domain contract provides it; the Composition Root never invents a capability (ARC-002, DES-009 §6).

## 7. Initial Implementation Plan

Implementation follows the MVP v0.1 Roadmap (`MVP_V01_ROADMAP.md` §Implementation Sequence). Each phase:

- introduces only APIs justified by this inventory and the roadmap;
- keeps the package building and its tests green at every step;
- completes with the contract documented and the API covered by tests before any cross-package consumer is added.

### Phase 1 — Composition Root and Storage Layout

Order: the OmniaApp package and library target — the composition contract of §3.1 over the storage layout of §3.2: the storage root derivation, the four file repositories, the `SecureCredentialStorage`, the application services over the injected Domain contracts, the runtime provider adapter binding of §3.3, and the presentation surfaces over their frozen seams (DES-010 §3.1, §3.4, §3.6; DES-011; DES-012 §3.6), with the first-run bootstrap of §3.4 tested on the Linux build environment.

### Phase 2 — Runtime Provider Adapter Binding

Order: the binding of §3.3 — reading the recorded credential reference and endpoint from the provider-settings configuration and constructing the bound adapter over the default transport, delivered as the `StreamingContract`/`TextGenerationContract` the send-message use case consumes (DES-010 §3.6, §3.9; DES-011 §3.3, §3.9).

### Phase 3 — App Shell, Entry Point, and Lifecycle

Order: the executable target — the SwiftUI `@main` App on macOS that launches the Composition Root, runs the bootstrap, builds the navigation surface, and hosts `RootView` with the resolved workspace and configuration keys (DES-013 §3.5, DES-012 §3.5), isolated behind platform availability (§3.6).

### Phase 4 — Package Verification

The full verification of the package against the completion criteria of the roadmap: the platform-independent Composition Root and bootstrap logic covered by deterministic, black-box unit tests on the Linux build environment (DES-004 §5); the dependency graph limited to the five Omnia packages and acyclic; the Composition Root verified as the only Infrastructure reference point; no business logic, networking, persistence, provider code, or credential operation leaving its owning layer; the public surface matching the frozen §3 exactly; the executable entry point isolated behind platform availability and verified by review (PRD-008 §Acceptance Criteria).

No API beyond the categories of Section 3 enters the package in these phases. Each phase ends in a state that is a valid, documented, tested increment of the public contract. The implementation realizes exactly the frozen surface of §3; a deviation from that surface is a defect and is resolved by correcting the implementation, never by silently changing the surface (DES-004 §1).

## Related Documents

- `Documentation/Product/Roadmap/MVP_V01_ROADMAP.md` — the roadmap that sequences this contract and the App Contract Freeze.
- `Documentation/Design/APPLICATION_API.md` — the frozen Application contract this package composes (DES-011 v1.1.0).
- `Documentation/Design/PRESENTATION_API.md` — the frozen Presentation contract this package hosts (DES-012 v1.1.0).
- `Documentation/Design/DOMAIN_API.md` — the frozen Domain contract whose implementations the Composition Root binds.
- `Documentation/Design/INFRASTRUCTURE_API.md` — the frozen Infrastructure contract whose implementations the Composition Root injects.
- `Documentation/Design/FOUNDATION_API.md` — the parent contract of the package this package depends on.
- `Documentation/Design/API/API_DESIGN_GUIDELINES.md` — the standard every API specification follows.
- `Documentation/Design/API/IDENTIFIER_API.md` — the identity primitive the bootstrap records and resolves.
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
- `.ai/context/PROJECT_STATE.md`
