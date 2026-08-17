# M3: Persistence + Security Report

## Summary

Implemented file-backed persistence, credential security, clear data, and process-restorable state for the Android Kotlin codebase, porting v1.0.0 iOS semantics into two new modules: `:core:data` and `:core:security`.

## Modules Created

### `:core:data` (Android Library)
- **Namespace:** `com.omnia.data`
- **Dependencies:** `:core:domain`, `:core:common`, `kotlinx-serialization-json`, `kotlinx-coroutines-core`
- **No Android framework dependencies in domain/application layers.**

### `:core:security` (Android Library)
- **Namespace:** `com.omnia.security`
- **Dependencies:** `:core:domain`, `:core:common`, `kotlinx-coroutines-core`

## Files Created

### `:core:data` Production Sources (14 files)
| File | Purpose |
|---|---|
| `JsonDocumentStore.kt` | Atomic JSON file store with Mutex, temp-file+rename, `loadJsonRecoveringInvalid`, `deleteAll` |
| `StorageLayout.kt` | Deterministic `filesDir/omnia/{conversations,providers,workspaces,configuration,attachments}` |
| `conversation/ConversationDTO.kt` | `@Serializable` DTOs + `ConversationSerializer` (toDTO/fromDTO with streaming state replay) |
| `conversation/FileConversationRepository.kt` | Implements `ConversationRepository`, `allConversations()`, `removeAll()` |
| `provider/ProviderDTO.kt` | `@Serializable` DTOs + `ProviderSerializer` (toDTO/fromDTO with `Provider.atState`) |
| `provider/FileProviderRepository.kt` | Implements `ProviderRepository`, `removeAll()` |
| `workspace/WorkspaceDTO.kt` | `@Serializable` DTOs + `WorkspaceSerializer` |
| `workspace/FileWorkspaceRepository.kt` | Implements `WorkspaceRepository` |
| `configuration/ConfigurationDTO.kt` | `ConfigurationSerializer` with type registry, schema version envelope |
| `configuration/FileConfigurationRepository.kt` | Implements `ConfigurationRepository`, `removeAll()`, type registration passthrough |
| `attachment/FileAttachmentStorage.kt` | Implements `AttachmentStorageProtocol`, path traversal prevention, bounded reads |

### `:core:security` Production Sources (2 files)
| File | Purpose |
|---|---|
| `InMemoryCredentialStorage.kt` | JVM-test credential storage, `removeAllCredentials()`, `storedReferences()` |
| `SecureCredentialStorage.kt` | Android Keystore AES/GCM with SharedPreferences ciphertext, `removeAllCredentials()`, `storedReferences()` |

### Test Sources (8 files, 90 tests)
| File | Tests |
|---|---|
| `JsonDocumentStoreTest.kt` | 16 tests: round-trip, replace, absent load, key isolation, delete, idempotent, allKeys, deleteAll, recoverInvalid, slash rejection, concurrent writes, atomic save |
| `FileConversationRepositoryTest.kt` | 17 tests: empty/history/streaming/modelSelection/title round-trip, replace, absent, delete, allConversations, malformed skip, removeAll, fresh-instance process-restoration (x2) |
| `FileProviderRepositoryTest.kt` | 15 tests: lifecycle state round-trip, connection preservation, replace, absent, allProviders, malformed skip, delete, removeAll, fresh-instance process-restoration (x2) |
| `FileConfigurationRepositoryTest.kt` | 17 tests: String/Int/Boolean/CredentialReference/ProviderAPIKind round-trip, replace, level isolation, key isolation, remove, removeAll, credential material exclusion, privacy sentinel, fresh-instance process-restoration, envelope verification |
| `FileWorkspaceRepositoryTest.kt` | 12 tests: round-trip, conversations/providers preservation, replace, absent, allWorkspaces, malformed skip, delete, fresh-instance process-restoration (x2) |
| `FileAttachmentStorageTest.kt` | 10 tests: byte round-trip, opaque key, bounded read, path traversal, remove, idempotent, durable copy, nonexistent, fresh-instance process-restoration |
| `InMemoryCredentialStorageTest.kt` | 11 tests: round-trip, replace, independence, not-found, remove, idempotent, removeAll, storedReferences, redaction, credential namespace purge, storedReferences-empty-after-purge |

## Key Design Decisions

### Type-Erasure Resolution
The `ConfigurationRepository` interface uses type-erased `T` generics, making round-trip of `CredentialReference` (inline class) and `ProviderAPIKind` (enum) impossible without additional type information. Solution:
1. `ConfigurationSerializer` maintains a `typeRegistry` mapping `KClass` → encode/decode lambdas
2. `ConfigurationEntrySchema` stores a `typeName` field alongside the payload
3. On store: the registered encoder converts the value to a string, and the type's `qualifiedName` is saved
4. On load: the stored `typeName` is used to find the registered decoder, which reconstructs the correct type
5. The composition root (`:app`) registers `CredentialReference` and `ProviderAPIKind` conversions

### Build System
- Pinned Gradle 8.13, AGP 8.13.2, Kotlin 2.3.21, kotlinx-serialization 1.9.0
- Migrated from deprecated `kotlinOptions { jvmTarget = "17" }` to `kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }`
- `kotlin-serialization` plugin applied at root level, consumed by `:core:data`

### Credential Storage
- Android Keystore AES/GCM-256 with randomized IV
- SharedPreferences ciphertext storage (raw keys never in JSON/preferences/logs)
- Complete credential namespace purgeable via `removeAllCredentials()`
- **BLOCKED:** Real-device Keystore verification not possible under Robolectric

## Verification

| Gate | Status |
|---|---|
| `:core:data:compileDebugKotlin` | PASS |
| `:core:security:compileDebugKotlin` | PASS |
| `test` (all modules) | PASS (304 total, 0 failures) |
| `lint` | PASS (0 errors) |
| `assembleDebug` | PASS |
| Architecture verification | PASS (no android/androidx references in core modules) |

## Test Counts
- `:core:data` — 87 tests
- `:core:security` — 11 tests
- `:core:application` — 98 tests (1 added: DataManagementService end-to-end clear)
- **Total M3 tests — 90** (in core:data + core:security)
- **Total project tests — 304**

## Acceptance Evidence

| # | Requirement | Evidence |
|---|---|---|
| 1 | Process-restoration | Fresh instance tests for all 5 repos + attachment storage: create repo, save, create new instance from same dir, load and verify |
| 2 | Malformed-record isolation | Tests in conversation/provider/workspace repos: write valid + malformed JSON, verify valid records load and malformed file is preserved |
| 3 | Credential security | `InMemoryCredentialStorage`: round-trip, purge, redaction. `SecureCredentialStorage`: Android Keystore AES/GCM (BLOCKED: not testable under Robolectric) |
| 4 | Credential namespace purge | `removeAllCredentials_deletesEveryCredentialAndIsIdempotent` + `removeAllCredentials_purgesOrphanedReferences` + `storedReferences_returnsEmptyAfterPurge` |
| 5 | Clear data | `DataManagementService.clearAll_wipesAllDataThroughLambda` + `removeAll` tests on all repositories |
| 6 | Privacy sentinel | `storedDocument_neverContainsSupersensitivePlaintext`: stores CredentialReference, verifies actual secret key never appears in config JSON |
| 7 | Appearance persistence | M0 scope, not M3. Infrastructure (FileConfigurationRepository) supports it. |
| 8 | Model catalog cache | M0 scope. Infrastructure supports durable configuration via FileConfigurationRepository. |
| 9 | Schema/versioning | `persistedDocument_carriesExpectedEnvelope`: verifies typeName, level, key fields in persisted JSON |
| 10 | Atomic storage | JsonDocumentStore uses Mutex + temp-file+rename. `concurrent_writesAndLoadsDoNotCorrupt`: 20 parallel writes verified. `save_isAtomic_noPartialWriteOnDirectoryListing` |
| 11 | Attachment security | Path traversal prevention tested. Bounded reads tested. Fresh instance persistence tested. |
| 12 | Type-erasure | ConfigurationSerializer type registry + typeName in schema. CredentialReference and ProviderAPIKind round-trip verified. |

## Known Limitations
- `SecureCredentialStorage` uses `Context.MODE_PRIVATE` SharedPreferences, requiring a real Android context (not testable under pure JUnit)
- `ConfigurationSerializer` type registry is a global mutable singleton (acceptable for single-process app)
- No schema migration mechanism yet — schema version envelope is present but no v1→v2 migration code
