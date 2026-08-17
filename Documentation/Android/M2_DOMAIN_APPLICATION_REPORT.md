# M2: Domain + Application Layer Contracts — Report

**Date:** 2026-08-17
**Commit:** (pending)
**Status:** COMPLETE (M2 Hardening Pass applied)

---

## Summary

Ported the Omnia v1.0.0 Domain and Application contract layers from Swift into pure Kotlin/JVM modules. All M2 gates pass: compilation clean, 72 domain tests + 93 application tests = 165 total tests passing, zero Android framework imports in domain/application, lint clean, `assembleDebug` APK builds successfully.

## Files Changed

| Module | Source files | Source lines | Test files | Test lines |
|--------|-------------|-------------|-----------|-----------|
| `core:common` | 1 | 20 | 0 | 0 |
| `core:domain` | 17 | ~1,100 | 11 | ~850 |
| `core:application` | 14 | ~1,050 | 11 | ~1,400 |
| **Total** | **32** | **~2,170** | **22** | **~2,250** |

**Total: 54 files, ~4,420 lines**

## M2 Hardening Pass — Bugs Fixed

### 1. `Conversation.append` auto-title (v1 parity gap)
Swift's `append` sets the title from the first user message inline. Kotlin had a separate `autoTitle()` method but never called it during `append`. **Fixed:** `append` now auto-derives title from first user message with whitespace normalization and 80-char truncation.

### 2. `Conversation.mergeMetadata` wrong semantics (v1 behavior bug)
Swift: when both snapshots have user titles, the newer repository snapshot's user title always wins. Kotlin: kept the older snapshot's user title. **Fixed:** corrected to match Swift — newer user title wins.

### 3. `Conversation.rename` missing whitespace normalization
Swift normalizes titles by collapsing whitespace (`"Hello   World"` → `"Hello World"`). Kotlin only trimmed. **Fixed:** `rename` and `append` auto-title now normalize via `normalizeTitle()`.

### 4. `SendMessageUseCase.prepareSend` missing `beginStreaming()`
The send flow appended the user message but never called `beginStreaming()`, causing `ConversationStreamError.NotStreaming` when `consume()` tried `appendPartial()`. **Fixed:** `prepareSend` now calls `beginStreaming()` after `append()`.

### 5. `ProviderConnectionService` missing endpoint/model/apiKind methods
Swift has `configure(request, endpoint, model, apiKind)`, `updateEndpoint`, `updateModel`, `updateAPIKind`, and full `update(request, identity, endpoint, model, apiKind)`. Kotlin only had basic `configure(request)`. **Fixed:** Added all missing methods with endpoint URL validation (http/https) and model trimming, matching Swift's `validatedEndpoint` and `validatedModel`.

### 6. `ProviderModelService.refreshCatalog` stale/failed distinction
Swift distinguishes stale (has cache), unavailable (has fallback), and failed (nothing). Kotlin always returned stale. **Fixed:** catch block now returns the correct status variant.

### 7. `ConversationServiceTest.conversationsIn_returnsSorted` flaky test
Test used fixed timestamps and relied on random UUID ordering. **Fixed:** uses a mutable `now` lambda to create deterministic ordering.

## Test Count: 165

### Domain Tests (72)

| File | Tests |
|------|-------|
| `ConversationTest.kt` | 27 — state machine, streaming, title, mergeMetadata, auto-title in append, whitespace normalization |
| `StreamingTypesTest.kt` | 6 — append, complete, interrupt, terminal check |
| `WorkspaceTest.kt` | 6 — membership, add/remove, idempotent, blank rejection |
| `ProviderSelectionTest.kt` | 5 — priority chain, unavailable, automatic, failure |
| `ProviderTypesTest.kt` | 5 — state machine transitions, canDeliver, replacingConnection |
| `ConfigurationTypesTest.kt` | 4 — key validation, resolution order, highest-priority wins |
| `ProviderLifecycleServiceTest.kt` | 4 — register, transition, unregister, providersReady |
| `ModelSelectionTest.kt` | 4 — selection value semantics, blank rejection |
| `ModelCapabilityProfileTest.kt` | 3 — supportFor, replacing, overlap rejection |
| `IdentityTypesTest.kt` | 5 — equality, value semantics |
| `CapabilityTest.kt` | 2 — case count, realized set |

### Application Tests (93)

| File | Tests |
|------|-------|
| `ProviderConnectionServiceTest.kt` | 23 — configure, endpoint, model, apiKind, update, remove, validation |
| `ProviderModelServiceTest.kt` | 20 — catalog, cache, refresh, stale/failed, default selection, capability profiles |
| `SendMessageUseCaseTest.kt` | 13 — send, resume, stale identity, interruption, error handling, metadata preservation |
| `AttachmentServiceTest.kt` | 7 — staging, limits, detection, normalization |
| `ConversationServiceTest.kt` | 8 — CRUD, rename, delete, workspace detach, sorting |
| `ConversationDraftServiceTest.kt` | 4 — save, retrieve, blank removes, remove |
| `ConfigurationServiceTest.kt` | 5 — store, retrieve, remove, resolved priority, blank key |
| `WorkspaceServiceTest.kt` | 4 — create, blank rejection, retrieve, null for missing |
| `ProviderValidationServiceTest.kt` | 4 — candidate success, endpoint rejection, credential rejection, existing test delegation |
| `DataManagementServiceTest.kt` | 3 — clearAll, exception propagation, invocation count |
| `ProvideAppMetadataTest.kt` | 2 — metadata values (M1) |

## Gate Results

| Gate | Result |
|------|--------|
| `./gradlew :core:domain:test :core:application:test` | **PASS** — 165 tests green |
| `./gradlew lint` | **PASS** — 0 errors |
| `./gradlew assembleDebug` | **PASS** — APK builds successfully |
| Architecture gate | **PASS** — 0 `android.*`/`androidx.*` imports in `core:domain` or `core:application` source |

## Error Taxonomy Coverage

All 14 error categories are represented across Domain and Application layers:

| Category | Domain Type | Application Type |
|----------|-------------|------------------|
| Provider unavailable | `CapabilityError.ProviderUnavailable` | — |
| Network unavailable | `CapabilityError.NetworkUnavailable` | — |
| Unauthorized | `CapabilityError.Unauthorized` | — |
| Invalid endpoint | `CapabilityError.InvalidEndpoint` | `ApplicationValidationError.Invalid` |
| Timed out | `CapabilityError.TimedOut` | — |
| Rate limited | `CapabilityError.RateLimited` | — |
| Server failure | `CapabilityError.ServerFailure` | — |
| Model unavailable | `CapabilityError.ModelUnavailable` | — |
| Invalid request | `CapabilityError.InvalidRequest` | `ApplicationValidationError.Invalid` |
| Invalid response | `CapabilityError.InvalidResponse` | — |
| Streaming interrupted | `CapabilityError.StreamingInterrupted` | — |
| Stream in progress | `ConversationStreamError.StreamInProgress` | — |
| Not streaming | `ConversationStreamError.NotStreaming` | — |
| Invalid title | `ConversationMetadataError.InvalidTitle` | — |
| Attachment errors (14 cases) | `AttachmentError.*` | — |
| Credential errors | `CredentialStorageError.*` | — |
| Repository errors | `RepositoryError.*` | — |

## Key Design Decisions

1. **No Swift translation** — Types were designed for Kotlin idioms, not line-by-line ported
2. **`for` is a keyword** — All Swift `external_parameter` names eliminated
3. **`partialContent` shadowing** — Renamed data class properties to `content` with computed getter
4. **ProviderSelectionPolicy over ProviderSelectionService** — Pure policy class, no service wrapper
5. **ProviderConnectionTestError as enum, not exception** — Application wraps into `ApplicationValidationError`
6. **ConfigurationRepository uses positional args** — No `for`/`at` named parameters

## Not Implemented (Deferred to M3+)

- Provider networking (Infrastructure)
- Room persistence (Infrastructure)
- Encrypted credential storage (Infrastructure)
- Android pickers / Compose UI flows
- Real provider validation HTTP calls
