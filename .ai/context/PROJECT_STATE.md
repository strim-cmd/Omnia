version: 0.1.0-alpha

phase: Infrastructure

status: Active

current_sprint: Domain Sprint 2

current_milestone: Domain Sprint 2

repository_foundation: Complete
ai_foundation: Complete
product_foundation: Complete
architecture_foundation: Complete
design_foundation: Complete
foundation_api: Frozen (v1)
domain_api: Frozen (v1)
domain_capability_contract_extension: Frozen (v1)
infrastructure_api: Frozen (v1)
omnia_foundation: Complete

completed:
  - Repository Foundation
  - AI Foundation (AI_CONSTITUTION.md, agents, standards, pipelines, prompts, templates)
  - Product Foundation (VISION.md, PRODUCT_CHARTER.md, PRODUCT_PRINCIPLES.md)
  - Architecture Foundation (01_SYSTEM_OVERVIEW.md through 06_DEPENDENCY_INJECTION.md, ADR-0001, ADR-0002)
  - Design Foundation (FOUNDATION_API.md, API specifications DES-001..DES-008)
  - Foundation Sprint 1 – Foundation API Specification and Freeze
  - Foundation API Freeze v1 (DES-001..DES-008 approved)
  - Foundation Phase 1 complete (Identifier, Environment, Lifecycle)
  - Foundation Phase 2 primitives (Logging, Clock, Cancellation)
  - SemanticVersion value type (DES-001 Phase 3 justified instance)
  - Foundation Sprint 2 – Implementation
  - OmniaFoundation package complete (Identifier, Environment, Lifecycle, Logging, Clock, Cancellation, SemanticVersion; 136 tests green)
  - Domain Sprint 1 – Implementation (DES-009 phases 1-8): value objects, capability contract and provider model, configuration model, credential storage protocol, aggregates, repository protocols, domain services and policies
  - OmniaDomain package complete (value objects, capability contract, configuration model, credential storage protocol, aggregates, four repository protocols, two domain services, two policies; 231 tests green)
  - Domain Sprint 1 milestone closed (2026-08-04); GitHub issues #7-#13 closed; PRs #14-#21 merged
  - Infrastructure Sprint 1 planned (2026-08-04); roadmap INFRASTRUCTURE_SPRINT_1_ROADMAP.md; GitHub issues #22-#31 created under milestone #6 with dependencies, acceptance criteria, and implementation order
  - AI framework command mode (2026-08-04): short task-oriented commands are the preferred interface; AI Constitution Task Execution rules (CONST-001 v1.1.0) and README command reference added; framework version 2.3.0
  - AI framework command mode finalized (2026-08-04): single Intent-Driven Operation principle (CONST-001 v1.2.0) — user prompts express intent only, workflows are discovered automatically, GitHub Issues/PRs/Milestones and PROJECT_STATE are the authoritative project state, `.ai` is the single source of engineering process truth; every workflow, checklist, and task references Command Mode consistently; framework version 2.4.0
  - AI framework Interactive Execution Mode added (2026-08-04): "Complete Issue #N" runs the full issue lifecycle automatically — implementation, PR creation, review, merge, and issue closure — via the Interactive Execution workflow (issue-lifecycle.md) and the complete-issue task; decision gates: blocking review issues fixed automatically, clean reviews merged automatically, non-blocking recommendations summarized and confirmed in the user's preferred language; engineering artifacts always in English, user interaction in the user's preferred language; CONST-001 v1.3.0; framework version 2.5.0
  - Workflow Orchestrator implemented (2026-08-04): the execution engine behind intent-driven commands — deterministic, registry-driven dispatch (orchestrator/REGISTRY.md), repository-derived state, always-resumable execution, decision gates (blocking auto-fix, clean auto-merge, non-blocking interactive); moved workflow orchestration from prompts into the repository; CONST-001 v1.4.0; framework version 3.0.0 (EP-002, issue #45)
  - Infrastructure API Freeze v1 (2026-08-04); DES-010 INFRASTRUCTURE_API.md ratified; GitHub issue #22 complete
  - Infrastructure Sprint 1 Phase 2 complete (2026-08-04): file-based JSON document store foundation (JSONDocumentStore) — save, load, delete, and list by identity; JSON serialization plumbing; storage-error translation to RepositoryError.storageUnavailable; 11 deterministic unit tests green on the Linux build (issue #23)
  - Infrastructure Sprint 1 Phase 3 complete (2026-08-04): Infrastructure-owned DTOs and JSON serializers for the Workspace, Conversation (with full message history), Provider (connection and lifecycle state), and configuration aggregates — WorkspaceSerializer, ConversationSerializer, ProviderSerializer, ConfigurationSerializer; never credentials, only CredentialReference pointers; deterministic stored form (sorted keys/arrays) that round-trips exactly; 29 serializer unit tests green on the Linux build (issue #24)
  - Infrastructure Sprint 1 Phase 4 complete (2026-08-04): Workspace and Conversation repository implementations over the storage engine and serializers — FileWorkspaceRepository and FileConversationRepository, each owning its document directory, storing whole aggregates by identity (full message history and streaming state for Conversation), save-replaces-by-identity, idempotent delete, no business rules (ARC-005), storage failures translated to RepositoryError.storageUnavailable; 16 deterministic unit tests green on the Linux build (issue #25)
  - Infrastructure Sprint 1 Phase 5 complete (2026-08-04): Provider repository implementation — FileProviderRepository over the storage engine and Provider serializer, storing the declared connection and lifecycle state by identity, never credentials (ARC-004, ARC-005), save-replaces-by-identity, idempotent delete, stable listing order, storage failures translated to RepositoryError.storageUnavailable; 12 deterministic unit tests green on the Linux build (issue #26)
  - Infrastructure Sprint 1 Phase 6 complete (2026-08-04): Configuration repository implementation — FileConfigurationRepository over the storage engine and Configuration serializer, storing typed values per ConfigurationLevel (DES-009 §3.5–§3.6), addressed by document keys composed of the level's serialized name and the key's name; the frozen Domain contract leaves Value unconstrained (Equatable & Sendable), so the repository bridges with a type-erased JSON payload at the storage boundary; never credentials, a stored value may hold only a CredentialReference pointer (ARC-004, ARC-005); storage and type-mismatch failures translated to RepositoryError.storageUnavailable (DES-009 §3.9); 14 deterministic unit tests green on the Linux build (issue #27)
  - Infrastructure Sprint 1 Phase 7 complete (2026-08-04): Secure credential storage implementation — SecureCredentialStorage, the concrete CredentialStorageProtocol over a replaceable platform backend seam (CredentialStorageBackend): the Keychain backend on Apple platforms (kSecClassGenericPassword, update-on-duplicate replace that never destroys the stored credential on failure) and the in-memory actor backend for the Linux build and automated tests, selected by the default initializer (DES-010 §3.4, ARC-005); honors the contract failures exactly — credentialNotFound and storageUnavailable (DES-009 §3.9); secrets never enter logs, analytics, or any representation — Credential descriptions stay redacted (ARC-001, ARC-005); 9 deterministic unit tests green on the Linux build (issue #28)
  - Infrastructure Sprint 1 Phase 8 complete (2026-08-04): provider transport seam and OpenAI-compatible client — the internal chat-completions DTOs and JSON serialization, SSE streaming primitives (CRLF-normalized decoding), and failure translation into ProviderTransportError (raw transport errors never leak); 28 tests green on the Linux build (issue #29)
  - Infrastructure Sprint 1 Phase 9 complete (2026-08-04): OpenAICompatibleProviderAdapter — the adapter shell conforms to the realized capability contracts (TextGenerationContract, ConversationContract, StreamingContract), wires the transport and the credential storage, owns no business logic or application state, and probes live availability through the transport seam in Omnia's own terms; 8 tests green on the Linux build (issue #30)
  - Infrastructure Sprint 1 Phase 10 complete (2026-08-04): package verification — full unit-test pass on the integrated branch (OmniaInfrastructure 136, OmniaDomain 231, OmniaFoundation 136, root 1); dependency verification that OmniaInfrastructure depends only on OmniaDomain and OmniaFoundation (ARC-009); layer verification that no UI framework, business rules, or presentation state enter the package and that platform backends (Keychain, FoundationNetworking) are isolated behind conditional compilation; internal dependency graph confirmed acyclic; credential material never in logs (ARC-001, ARC-005); black-box coverage added for the adapter's public initializer (issue #31)
  - Infrastructure Sprint 1 milestone closed (2026-08-04); GitHub issues #22-#31 closed; all phase PRs merged into feature/repository-foundation
  - Infrastructure Sprint 1 retrospective complete (2026-08-04): RETRO-001 ratified — achievements, engineering successes, recurring problems, workflow pain points, tooling observations, process improvements, and the Engineering Platform v2 backlog (issue #43); no improvements implemented, per the issue scope
  - EP-001 follow-up complete (2026-08-04): RETRO-002 ratified — documented how EP-002 (Workflow Orchestrator) validated the orchestrator architecture (ORCH-000) from execution evidence: intent-to-workflow transformation, registry-driven dispatch, repository-derived state, clean and non-blocking decision gates, language separation, minimal interaction, and repository-derived recovery; blocking gate, command-pattern rejection, and RFC gate recorded as not yet exercised (issue #48)
  - Engineering Command Interface established (2026-08-04): the single supported user interaction surface of the Engineering Platform — command grammar (Verb [Object]), canonical supported command set defined by the Workflow Registry, registry-based resolution, and unrecognized commands reported and never executed; CMD-000 ratified; CONST-001 v1.5.0; framework version 3.1.0 (EP-003, issue #51)
  - Engineering Platform Validation Suite established (2026-08-04): the repository-defined set of checks that certifies the integrity of the Engineering Platform itself — reference resolution, registry integrity, version and identifier consistency, document structure, absence of placeholders, style artifacts, and absence of contradictions; invocable as the `Validate Engineering Platform` command; VAL-000 ratified; CONST-001 v1.6.0; framework version 3.2.0 (EP-004, issue #53)
  - Workflow Orchestrator execution-path validation complete (2026-08-04): EP-005 exercised the three previously untested orchestrator paths (ORCH-000) — RFC gate (Design workflow + RFC-001 created and ratified as exercise), command-pattern rejection (non-registry command reported in user's preferred language and never executed), and blocking gate (controlled defect auto-fixed, verification re-run, review repeated until clean); RETRO-003 ratified; every ORCH-000 property now validated by observed execution (EP-005, issue #55)
  - Engineering Platform v1 closed (2026-08-04): RFC-002 ratified (Accepted) — Engineering Platform v1 (FRAMEWORK-001 v3.2.0, CONST-001 v1.6.0, ORCH-000, CMD-000, VAL-000, PIPELINE-000) complete and validated; milestone #13 Engineering Platform v1 closed; milestone #14 Engineering Platform v2 created as planning only — roadmap tracks (Realization integration, Automation, Verification, Governance and tooling) from RETRO-001 backlog + pipeline dispatch integration + RFC-001; no v2 item implemented
  - First v2 Realization integration complete (2026-08-04): EP-006 wired the New Document Pipeline into `Create Document` dispatch — `Pipeline` column added to the Workflow Registry (ORCH-REG-001 v1.1.0), `Create Document` row resolves through PIPELINE-001, pipeline-resolution rule and attachment procedure added; documentation workflow and create-document task follow NEW_DOCUMENT_PIPELINE stages; Validation Suite registry-integrity check extended to resolve every populated `Pipeline` field (VAL-000 v1.1.0); backward compatible — same document artifact and same documentation-review checklist; framework version 3.3.0 (EP-006, issue #58)
  - Engineering Platform Validation Suite automated (2026-08-04): EP-007 added the validation script `.ai/scripts/validate-platform.sh` (VAL-000 v1.2.0) as the primary execution mechanism — deterministic encoding of all validation categories with per-category pass/fail output and a non-zero exit on failure; the manual checklist remains the authoritative specification and fallback; platform-validation workflow and validate-platform task run the script and reconcile with the checklist; fixed a broken registry reference in the documentation workflow; added `.gitattributes` (`*.sh text eol=lf`); framework version 3.4.0 (EP-007, issue #60)
  - Second v2 Realization integration complete (2026-08-04): EP-008 wired the Architecture Review Pipeline into `Review PR #N` dispatch — `Review PR #N` row's `Pipeline` column populated with `pipelines/ARCHITECTURE_REVIEW_PIPELINE.md` (PIPELINE-002) in the Workflow Registry (ORCH-REG-001 v1.2.0), reusing the generic `Pipeline` column mechanism, resolution rule, and attachment procedure from EP-006 without introducing command-specific orchestration logic; review workflow and review-pr task follow ARCHITECTURE_REVIEW_PIPELINE stages for architecture-relevant artifacts, preserving the pipeline's exclusions and the command's inputs, outputs, and acceptance path; backward compatible; framework version 3.5.0 (EP-008, issue #62)
  - Domain Sprint 2 planned (2026-08-04): roadmap DOMAIN_SPRINT_2_ROADMAP.md (PRD-004) — the Domain capability-contract extension (DES-009 v0.2.0 → v0.3.0): concrete capability value objects, capability errors, concrete contract methods, and streaming behavior, sequenced before the concrete provider capabilities; GitHub issues #64-#70 created under milestone #5 with dependencies, acceptance criteria, and implementation order
  - Infrastructure Sprint 2 planned (2026-08-04): roadmap INFRASTRUCTURE_SPRINT_2_ROADMAP.md (PRD-005) — the concrete provider capabilities (Text Generation, Conversation, Streaming) on the OpenAI-compatible adapter over the existing transport seam (DES-010 v1.0.0 → v1.1.0, additive); depends on the Domain capability extension (PRD-004); GitHub issues #71-#76 created under milestone #7 with dependencies, acceptance criteria, and implementation order
  - Domain Capability Contract Extension Freeze (2026-08-05): DES-009 DOMAIN_API.md v0.3.0 ratified — the capability contract extension of Domain Sprint 2 Stage 1: the capability request, response, and streaming value objects; the capability error abstraction; the concrete methods on TextGenerationContract, ConversationContract, and StreamingContract; and the streaming behavior, additive and backward-compatible over Domain API Freeze v1; reviewed with the documentation review checklist and verified against ARC-002, ARC-004, ARC-007, ARC-008, ARC-009, ADR-0001/ADR-0002, and the frozen Foundation API (DES-001..DES-008) (issue #64)
  - Domain Capability Design Frozen (2026-08-05): Domain Sprint 2 Stage 2 complete — the concrete design of the capability extension detailed within DES-009 v0.3.0 (§3.11) and frozen as the single source of truth for implementation: the value-object inventory (CapabilityRequestIdentity on Identifier, TextGenerationRequest/Response, ConversationRequest/Response, StreamingRequest, StreamingUpdate events), the capability error taxonomy (CapabilityError: providerUnavailable, invalidRequest, invalidResponse, streamingInterrupted(partialContent:)), the concrete contract methods (generateText, sendMessage, stream), and the streaming state machine (active, complete, interrupted) with legal transitions; reviewed with the documentation review checklist (issue #65)

milestones:
  Foundation API Freeze v1:
    Status: Approved
    Scope:
      - DES-001 FOUNDATION_API
      - DES-002 IDENTIFIER_API
      - DES-003 CLOCK_API
      - DES-004 API_DESIGN_GUIDELINES
      - DES-005 LOGGER_API
      - DES-006 ENVIRONMENT_API
      - DES-007 LIFECYCLE_API
      - DES-008 CANCELLATION_API
    Outcome:
      - Public API frozen.
      - Future API changes require specification revision.
      - Implementation proceeds against frozen contracts.
  Foundation Sprint 2 – Implementation:
    Status: Complete
    Scope:
      - DES-001 Phase 1 primitives (Identifier, Environment, Lifecycle)
      - DES-001 Phase 2 primitives (Logging, Clock, Cancellation)
      - DES-001 Phase 3 justified instance (SemanticVersion)
    Outcome:
      - OmniaFoundation package implemented.
      - 136 tests passing.
  Domain API Freeze v1:
    Status: Approved
    Scope:
      - DES-009 DOMAIN_API
    Outcome:
      - Public API frozen.
      - Future API changes require specification revision.
      - Implementation proceeds against frozen contracts.
  Domain Capability Contract Extension Freeze:
    Status: Ratified
    Scope:
      - DES-009 DOMAIN_API v0.3.0 capability contract extension
    Outcome:
      - Public API extended additively over Domain API Freeze v1.
      - Capability contract frozen; a further change requires specification revision.
      - Implementation of the extension proceeds against the frozen contract.
  Infrastructure API Freeze v1:
    Status: Ratified
    Scope:
      - DES-010 INFRASTRUCTURE_API
    Outcome:
      - Public API frozen.
      - Future API changes require specification revision.
      - Implementation proceeds against frozen contracts.
  Domain Sprint 1 – Implementation:
    Status: Complete
    Scope:
      - DES-009 Phase 1 value objects
      - DES-009 Phase 2 capability contract and provider model
      - DES-009 Phase 3 configuration model and resolution policy
      - DES-009 Phase 4 credential storage protocol
      - DES-009 Phase 5 aggregates
      - DES-009 Phase 6 repository protocols
      - DES-009 Phase 7 domain services and policies
      - DES-009 Phase 8 package verification
    Outcome:
      - OmniaDomain package implemented against the frozen contract.
      - OmniaDomain depends only on OmniaFoundation; dependency graph acyclic; no forbidden imports.
      - 231 tests passing, verified on the fully integrated branch (PRs #14–#21); 0 build or test warnings.
      - Milestone closed 2026-08-04; all Phase issues #7-#13 closed; all PRs #14-#21 merged into feature/repository-foundation.
  Infrastructure Sprint 1 – Implementation:
    Status: Complete
    Scope:
      - DES-010 Infrastructure API specification and freeze (complete)
      - Storage engine foundation (file-based JSON document store) (complete)
      - Aggregate serializers (complete)
      - Workspace and Conversation repository implementations (complete)
      - Provider repository implementation (complete)
      - Configuration repository implementation (complete)
      - Secure credential storage (Keychain backend seam + in-memory backend) (complete)
      - Provider transport and OpenAI-compatible client (complete)
      - Provider adapters (complete)
      - Package verification (complete)
    Outcome:
      - Planned 2026-08-04; roadmap and issues #22-#31 created under milestone #6.
      - DES-010 ratified 2026-08-04 (Infrastructure API Freeze v1, issue #22 closed).
      - Storage engine foundation complete 2026-08-04 (issue #23); 11 tests green on the Linux build.
      - Aggregate serializers complete 2026-08-04 (issue #24); 29 tests green on the Linux build; never credentials, only references.
      - Workspace and Conversation repository implementations complete 2026-08-04 (issue #25); 16 tests green on the Linux build.
      - Provider repository implementation complete 2026-08-04 (issue #26); 12 tests green on the Linux build.
      - Configuration repository implementation complete 2026-08-04 (issue #27); 14 tests green on the Linux build.
      - Secure credential storage implementation complete 2026-08-04 (issue #28); 9 tests green on the Linux build; secrets never enter logs or any representation.
      - Provider transport and OpenAI-compatible client complete 2026-08-04 (issue #29); 28 tests green on the Linux build (package suite 126 green); the `ProviderTransport` seam with no network in tests, the OpenAI-compatible HTTP client, internal chat-completions DTOs and JSON serialization, SSE streaming primitives, and failure translation into `ProviderTransportError` (raw errors never leak; credentials by reference, secrets confined to the authorization header).
      - Provider adapters complete 2026-08-04 (issue #30); 8 tests green on the Linux build (package suite 134 green); the `OpenAICompatibleProviderAdapter` shell conforms to the realized capability contracts (`TextGenerationContract`, `ConversationContract`, `StreamingContract`), wires the transport and the credential storage, owns no business logic or application state, and reports live availability through the transport seam in Omnia's own terms (ARC-004 Capability Discovery); concrete capability call methods deferred until the Domain contract is extended (DES-010 §3.6).
      - Package verification complete 2026-08-04 (issue #31); full unit-test pass on the integrated branch (OmniaInfrastructure 136, OmniaDomain 231, OmniaFoundation 136, root 1); OmniaInfrastructure depends only on OmniaDomain and OmniaFoundation (ARC-009); no UI framework, business rules, or presentation state in the package; platform backends (Keychain, FoundationNetworking) isolated behind conditional compilation; internal dependency graph acyclic; credential material never in logs; black-box coverage added for the adapter's public initializer (package suite 136 green).
      - Milestone closed 2026-08-04; all Phase issues #22-#31 closed; all phase PRs merged into feature/repository-foundation.
  Domain Sprint 2 – Implementation:
    Status: Active
    Scope:
      - DES-009 v0.3.0 Domain capability contract extension (specification and freeze)
      - Domain capability design and freeze (value objects, errors, methods, streaming behavior)
      - Capability value objects
      - Capability errors
      - Concrete contract methods (TextGenerationContract, ConversationContract, StreamingContract)
      - Streaming behavior (state machine: active, complete, interrupted)
      - Verification and test matrix
    Outcome:
      - Planned 2026-08-04; roadmap DOMAIN_SPRINT_2_ROADMAP.md (PRD-004); issues #64-#70 under milestone #5.
      - Stage 1 complete 2026-08-05: DES-009 v0.3.0 ratified (Domain Capability Contract Extension Freeze, issue #64).
      - Stage 2 complete 2026-08-05: capability design frozen within DES-009 v0.3.0 (§3.11, issue #65).
      - Extends the Domain contract so the concrete provider capabilities can be implemented in Infrastructure Sprint 2.
  Infrastructure Sprint 2 – Implementation:
    Status: Planned
    Scope:
      - DES-010 v1.1.0 Infrastructure capability specification and freeze
      - Capability mapping (Domain types to internal DTOs)
      - Text Generation capability (generateText over chat-completions)
      - Conversation capability (sendMessage over chat-completions)
      - Streaming capability (stream over SSE, completion and interruption events)
      - Package verification
    Outcome:
      - Planned 2026-08-04; roadmap INFRASTRUCTURE_SPRINT_2_ROADMAP.md (PRD-005); issues #71-#76 under milestone #7.
      - Sequenced after Domain Sprint 2 (PRD-004); depends on the extended Domain capability contract (DES-009 v0.3.0).

next_tasks:
  - Keep the package building and its tests green at every step
  - Implement remaining DES-001 Phase 3 primitives when required (shared value types, typed-error abstraction)
  - Continue Domain Sprint 2 (milestone #5): the capability contract extension is frozen (DES-009 v0.3.0) and the capability design is frozen (§3.11, issue #65); implement the extension against the frozen design per PRD-004 (issues #66-#70)
  - After Domain Sprint 2, kick off Infrastructure Sprint 2 (milestone #7): implement the concrete provider capabilities (issues #71-#76, PRD-005)
  - Engineering Platform v2 (milestone #14, planning only per RFC-002): schedule v2 roadmap items as individual GitHub issues — Track A realization integration (wire PIPELINE-001 into the registry dispatch DONE via EP-006; wire PIPELINE-002 into an architecture review command DONE via EP-008), Track B automation (RFC-001 validate-platform script DONE via EP-007; automated package verification), Track C verification (black-box package-surface suite, CI pipeline, docs-drift check), Track D governance and tooling (recurring retrospective template, review sign-off for security-sensitive changes, project-board CLI helper, start-sprint checklist)

blocked: []

known_issues: []

last_updated: 2026-08-05
