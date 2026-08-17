# M2: Domain + Application Layer Contracts — Report

**Date:** 2026-08-17
**Commit:** (pending)
**Status:** COMPLETE

---

## Summary

Ported the Omnia v1.0.0 Domain and Application contract layers from Swift into pure Kotlin/JVM modules. All M2 gates pass: compilation clean, 34 domain tests + application tests passing, zero Android framework imports in domain/application, lint clean, `assembleDebug` APK builds successfully.

## Files Changed

| Module | Source files | Source lines | Test files | Test lines |
|--------|-------------|-------------|-----------|-----------|
| `core:domain` | 17 | 1,044 | 11 | 605 |
| `core:application` | 14 | 962 | 7 | 508 |
| **Total** | **31** | **2,006** | **18** | **1,113** |

**Total: 49 files, ~3,119 lines**

## Domain Layer (`core:domain`)

### Source Files

| File | Purpose |
|------|---------|
| `IdentityTypes.kt` | Type-safe identity wrappers (Provider, Conversation, Workspace, Attachment, CredentialReference, ModelReference) |
| `Capability.kt` | 11-case capability enum with `realized` set |
| `CapabilityError.kt` | 11 normalized capability errors |
| `CapabilityContract.kt` | TextGeneration, Conversation, Streaming contract interfaces |
| `ProviderTypes.kt` | ProviderAPIKind, ProviderState, ProviderLifecycleError, ProviderCapabilities, ProviderMetadata, ProviderLimits, ProviderConnection, Provider aggregate |
| `ModelSelection.kt` | ProviderModelSelection, ModelDescriptorSource, ModelCapabilitySupport, ModelCapabilityProfile, ModelDescriptor |
| `ProviderSelection.kt` | ProviderSelectionPolicy (priority chain), ProviderCandidate, ProviderSelectionResult |
| `ProviderServices.kt` | ProviderLifecycleService (Mutex-guarded in-memory registry) |
| `Message.kt` | MessageRole, Message |
| `Conversation.kt` | Conversation aggregate (state machine: beginStreaming/appendPartial/completeStreaming/interruptStreaming/selectModel/rename/mergeMetadata/autoTitle), streaming state, errors |
| `StreamingTypes.kt` | StreamingState, StreamingUpdate, StreamingRequest, ConversationRequest, TextGenerationRequest |
| `AttachmentTypes.kt` | AttachmentKind, MessageAttachment, PreparedAttachmentContent, AttachmentPayload, ResolvedAttachment, AttachmentError |
| `RepositoryTypes.kt` | ConversationRepository, ProviderRepository, WorkspaceRepository interfaces, RepositoryError, ProviderConnectionTestError, ModelCatalogError |
| `Workspace.kt` | Workspace aggregate (membership by identity only, ARC-007) |
| `ConfigurationTypes.kt` | ConfigurationKey, ConfigurationLevel, ConfigurationValue, ConfigurationRepository, ConfigurationResolutionPolicy |
| `CredentialTypes.kt` | Credential (opaque with scoped withValue), CredentialStorageProtocol, CredentialStorageError, AttachmentStorageProtocol |
| `DomainError.kt` | Root domain error type |

### Test Files

| File | Tests |
|------|-------|
| `ModelSelectionTest.kt` | 4 tests — selection value semantics, blank rejection |
| `ConversationTest.kt` | 14 tests — state machine, streaming, title, mergeMetadata |
| `CapabilityTest.kt` | 2 tests — case count, realized set |
| `ProviderTypesTest.kt` | 5 tests — state machine transitions, canDeliver, replacingConnection |
| `StreamingTypesTest.kt` | 6 tests — append, complete, interrupt, terminal check |
| `WorkspaceTest.kt` | 6 tests — membership, add/remove, idempotent, blank rejection |
| `ProviderSelectionTest.kt` | 5 tests — priority chain, unavailable, automatic, failure |
| `ConfigurationTypesTest.kt` | 4 tests — key validation, resolution order, highest-priority wins |
| `IdentityTypesTest.kt` | 5 tests — equality, value semantics |
| `ModelCapabilityProfileTest.kt` | 3 tests — supportFor, replacing, overlap rejection |
| `ProviderLifecycleServiceTest.kt` | 4 tests — register, transition, unregister, providersReady |

## Application Layer (`core:application`)

### Source Files

| File | Purpose |
|------|---------|
| `AppMetadata.kt` | Static app metadata (M1, unchanged) |
| `ProvideAppMetadata.kt` | Seed use case (M1, unchanged) |
| `ApplicationValidationError.kt` | Boundary validation error |
| `ApplicationTypes.kt` | ConfigureProviderRequest, ProviderUpdateRequest, SendMessageRequest, AttachmentImportCandidate, AttachmentLimits |
| `ConfigurationService.kt` | Typed configuration service with boundary validation |
| `ConversationDraftService.kt` | Per-conversation draft persistence |
| `ConversationService.kt` | Conversation CRUD, model selection, rename, delete with workspace membership |
| `ProviderConnectionService.kt` | Provider configuration, credential storage, lifecycle wiring |
| `ProviderModelService.kt` | Model catalog management, caching, default selection, capability resolution |
| `ProviderValidationService.kt` | Provider connection testing (delegates to Infrastructure closures) |
| `SendMessageUseCase.kt` | 12-step orchestration: validate → load → select → append → resolve → stream → apply → persist → reconcile → finalize |
| `AttachmentService.kt` | Atomic staging, validation, resolution, orphan cleanup |
| `WorkspaceService.kt` | Workspace CRUD with boundary validation |
| `DataManagementService.kt` | Clear-all data management |

### Test Files

| File | Tests |
|------|-------|
| `ProvideAppMetadataTest.kt` | 2 tests (M1, unchanged) |
| `ConfigurationServiceTest.kt` | 5 tests — store, retrieve, remove, resolved priority, blank key |
| `ConversationServiceTest.kt` | 8 tests — CRUD, rename, delete, workspace detach, sorting |
| `AttachmentServiceTest.kt` | 7 tests — stage, limits, empty/oversized rejection, existing support, kind detection, normalization |
| `ConversationDraftServiceTest.kt` | 4 tests — save, retrieve, blank removes, remove |
| `WorkspaceServiceTest.kt` | 4 tests — create, blank rejection, retrieve, null for missing |
| `ProviderValidationServiceTest.kt` | 4 tests — candidate success, endpoint rejection, credential rejection, existing test delegation |

## Gate Results

| Gate | Result |
|------|--------|
| `./gradlew test` | **PASS** — 34 domain/application tests + M1 tests all green |
| `./gradlew lint` | **PASS** — 0 errors |
| `./gradlew assembleDebug` | **PASS** — APK builds successfully |
| Architecture gate | **PASS** — 0 `android.*`/`androidx.*` imports in `core:domain` or `core:application` source |

## Key Design Decisions

1. **No Swift translation** — Types were designed for Kotlin idioms, not line-by-line ported
2. **`for` is a keyword** — All Swift `external_parameter` names (`for`, `with`, `to`, `in`, `named`, `of`) were eliminated
3. **`partialContent` shadowing** — Renamed data class properties to `content` with computed `partialContent` getter
4. **ProviderSelectionPolicy over ProviderSelectionService** — Pure policy class for domain-level selection, no service wrapper
5. **ProviderConnectionTestError as enum, not exception** — Application layer wraps into `ApplicationValidationError` for throws
6. **ConfigurationRepository uses positional args** — No `for`/`at` named parameters to avoid keyword conflicts

## Not Implemented (Deferred to M3+)

- Provider networking (Infrastructure)
- Room persistence (Infrastructure)
- Encrypted credential storage (Infrastructure)
- Android pickers / Compose UI flows
- Real provider validation HTTP calls
