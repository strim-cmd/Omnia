# Autonomous Progress — Android v1.0.0 Build

**Status:** M0–M5 Complete — Feature-complete, all gates green
**Last updated:** 2026-08-18
**Latest commit:** `22ab71a` — `feat: Wire attachment service into Chat UI layer`

---

## Milestones

| Milestone | Description | Status |
|---|---|---|
| M0 | Contract freeze — Android 1.0 parity defined against iOS 1.0.0 | Done |
| M1 | Native application foundation — module tree, dependency rules, design system, CI | Done |
| M2 | Hardening pass — Stop/Retry/Continue parity, generation isolation, comprehensive tests | Done |
| M3 | Persistence & security — file-backed repos, credential storage, clear data, process-restorable state | Done |
| M4 | Network layer — core:network module, transport abstraction, SSE decoder, OpenAI-compatible & Gemini clients, DTOs, provider adapters/inspectors | Done |
| M5 | Composition root — AppContainer, ProviderAdapterBinding, real service graph | Done |

---

## Features

### Chat
- Conversation list with persistent titles, timestamps, search, and date grouping
- Message bubbles with streaming response display
- Code blocks with copy action
- Rename conversations
- Conversation generation coordinator (stop/retry/continue, generation isolation across navigation and background/foreground transitions)
- Unsent draft persistence and recovery

### Providers
- Full CRUD: list, add, edit, delete with confirmation dialog
- AddProviderScreen with API kind selector (OpenAI-compatible / Gemini)
- Model discovery with cached catalogs and coherent defaults
- Per-conversation model selection and capability gating
- Real connection testing
- First-launch Add Provider guidance

### Settings
- Clear Data with confirmation dialog (purges chats, attachments, settings, provider metadata, credentials)
- Appearance toggle: System / Light / Dark theme with persistence
- About Omnia screen (version, build info, credits)

### About
- Dedicated screen in app module (`AboutScreen.kt`)

### Attachments
- Domain layer: `AttachmentTypes.kt` — all attachment types (image, PDF, plain text)
- Application layer: `AttachmentService` — capability-aware validation, request routing, durable metadata, cleanup
- Data layer: `FileAttachmentStorage` — persistent file storage
- Wired into ChatDependencies, ChatViewModel, ChatUiState

---

## Module Architecture

```
app → features → designsystem → application → domain → common
                      ↓                ↓
                    data            network
                      ↓
                   security
```

| Module | Kind | Key Contents |
|---|---|---|
| `core:common` | pure JVM | Clock, Identifier, Logger, AppError, DispatcherProvider, SemanticVersion |
| `core:domain` | pure JVM | Conversation, Message, Provider, Capability, AttachmentTypes, ModelSelection, Workspace, StreamingTypes |
| `core:application` | pure JVM | ConversationService, ConversationGenerationCoordinator, AttachmentService, SendMessageUseCase, DataManagementService, ConfigurationService, ProviderValidationService, ProviderModelService, ProviderConnectionService |
| `core:designsystem` | Android lib | Theme (brand `#8A2BE2`), components, icons, spacing |
| `core:data` | pure JVM | FileConversationRepository, FileProviderRepository, FileConfigurationRepository, FileWorkspaceRepository, FileAttachmentStorage, JsonDocumentStore |
| `core:network` | pure JVM | OkHttpProviderTransport, SSEDecoder, OpenAI-compatible client + DTOs + mapping, Gemini client + DTOs + mapping, ProviderAdapter/Inspector, ProviderErrorMapping |
| `core:security` | pure JVM | SecureCredentialStorage (platform), InMemoryCredentialStorage (test) |
| `feature:chat` | Android lib | ChatScreen, ChatViewModel, ChatUiState, MessageBubble, ChatDependencies |
| `feature:providers` | Android lib | ProvidersScreen, ProvidersViewModel, AddProviderScreen, AddProviderUiState, ProvidersDependencies |
| `feature:settings` | Android lib | SettingsScreen, SettingsViewModel, SettingsUiState, SettingsDependencies |
| `app` | Android app | AppContainer (composition root), OmniaNavHost, OmniaDestination, MainActivity, OmniaApplication, AppThemeController, AboutScreen, ProviderAdapterBinding |

---

## Build Gates

| Gate | Command | Result |
|---|---|---|
| Build | `./gradlew assembleDebug` | **PASS** |
| Tests | `./gradlew test` | **PASS** (54 test files across 8 modules) |
| Lint | `./gradlew lint` | **PASS** (0 errors) |

---

## Test Coverage by Module

| Module | Test Files |
|---|---|
| `core:common` | ClockTest, IdentifierTest, LoggerTest |
| `core:domain` | ConversationTest, ConfigurationTypesTest, CapabilityTest, ModelCapabilityProfileTest, IdentityTypesTest, ProviderSelectionTest, ProviderLifecycleServiceTest, ModelSelectionTest, StreamingTypesTest, ProviderTypesTest, WorkspaceTest |
| `core:application` | AttachmentServiceTest, ConfigurationServiceTest, ConversationDraftServiceTest, ConversationServiceTest, DataManagementServiceTest, ProvideAppMetadataTest, ProviderConnectionServiceTest, ProviderModelServiceTest, ProviderValidationServiceTest, SendMessageUseCaseTest, WorkspaceServiceTest |
| `core:data` | FileAttachmentStorageTest, FileConfigurationRepositoryTest, FileConversationRepositoryTest, FileProviderRepositoryTest, FileWorkspaceRepositoryTest, JsonDocumentStoreTest |
| `core:network` | GeminiClientTest, GeminiMappingTest, OpenAICompatibleClientTest, OpenAIDTOSerializationTest, OpenAIMappingTest, OkHttpProviderTransportTest, ProviderErrorMappingTest, SSEDecoderTest, FixedCredentialStorageTest, GeminiProviderAdapterTest, OpenAIProviderAdapterTest, ProviderInspectorTest, ProviderPrivacyTest |
| `core:security` | InMemoryCredentialStorageTest |
| `core:designsystem` | ThemeTest |
| `feature:chat` | ChatScreenTest, ChatViewModelTest |
| `feature:providers` | ProvidersScreenTest, ProvidersViewModelTest |
| `feature:settings` | SettingsScreenTest, SettingsViewModelTest |
| `app` | ArchitectureVerificationTest, NavigationTest |

---

## Persistence & Security

- Pre-v1 serialized data remains readable with explicit defaults for newer fields
- Individually malformed records are isolated without deleting the rest
- API keys stored in platform secure credential storage
- Persisted records contain only safe metadata and opaque credential references
- Clear Data purges the complete Omnia credential namespace

---

## Known Limitations

- Emulator/device not run — UI validated via Robolectric Compose tests
- Compose UI tests run on Robolectric only (SDK 35) with LEGACY graphics mode
- JDK 21 would unlock full Robolectric SDK 36 sandbox and native graphics-mode tests
- Short-prompt framework, prompt library, voice, sync, workspaces, plugins, and built-in web/image generation deferred to post-v1
- Host environment requires `GRADLE_USER_HOME=C:\GradleHome` and `-Duser.home=C:\OmniaTestHome` (non-ASCII Windows profile workarounds)

---

## CI

`.github/workflows/android.yml` — Ubuntu, JDK 17 Temurin, runs on push/PR (path filter: `Android/**`):

- `./gradlew test`
- `./gradlew lint`
- `./gradlew assembleDebug`
- Uploads `omnia-android-debug` artifact
- Gradle wrapper validation included
