# Android Migration Map — Swift type → Android module/file mapping

| | |
| --- | --- |
| **Document** | ANDROID_MIGRATION_MAP |
| **Phase** | M0 — Contract Freeze |
| **Primary artifact** | Maps every iOS Swift source file/type to the Android module and proposed Kotlin file that will carry its parity behavior. |
| **Scope rule** | Maps the **contract surface** (types, invariants, behaviors) only — never Swift mechanics. See `ANDROID_ARCHITECTURE.md` §4 for what is deliberately not copied. |

## 1. Module mapping (top level)

| iOS package | Android module | Purpose |
| --- | --- | --- |
| `OmniaFoundation` | `:core` | Platform-agnostic value types, identity, clock, cancellation, logging, environment, lifecycle, semantic version |
| `OmniaDomain` | `:domain` | Aggregates, repository contracts, capability/credential/config/selection contracts, error taxonomy |
| `OmniaInfrastructure` | `:data` | File store + serializers, credential storage backends, HTTP transports, adapter/inspector/error-mapping, catalog cache |
| `OmniaApplication` | `:app` | Services and use cases (conversation, workspace, provider connection, configuration, send message, attachments, drafts, data management) |
| `OmniaPresentation` | `:presentation` | Screens, state models, surfaces, coordinator, Markdown, tokens, localization, accessibility |
| `OmniaApp` | `:app-shell` | Composition root, storage layout, adapter binding, first-run bootstrap, launch/constants |

## 2. Per-package mapping

### 2.1 `OmniaFoundation` → `:core`

| Swift file | Key types | Android target (proposed) | Notes |
| --- | --- | --- | --- |
| `Identifier.swift` | `Identifier<Kind>`, `IdentifierProvider`, restoring init | `:core` `Identifier<K>` + `IdKind` markers | Strict canonical restore per audit |
| `Clock.swift` | `Clock`, `Instant`, `MonotonicClock`, `SuspendedClock` | `:core` `Clock` + `Instant` | Injectable; monotonic |
| `Cancellation.swift` | `CancellationSource`, `CancellationObservation`, `CancelledOutcome` | `:core` `CancellationSource` | Cooperative cancel contract |
| `Logger.swift` | `Logger`, `LogEvent`, `LogMetadata`, `LogLevel`, `Sensitive` | `:core` `Logger` + `Sensitive` | Redaction contract (X-01) |
| `Environment.swift` | `Environment`, `Platform`, `ExecutionMode`, `EnvironmentCapability` | `:core` `Environment` + `Platform` | Composition-delivered facts |
| `Lifecycle.swift` | `Lifecycle<State>`, observers | `:core` `Lifecycle` state machine | |
| `SemanticVersion.swift` | `SemanticVersion` | `:core` `SemanticVersion` | |

### 2.2 `OmniaDomain` → `:domain`

| Swift file | Key types | Android target (proposed) | Notes |
| --- | --- | --- | --- |
| `Identifier` types (`ConversationIdentity`, `ProviderIdentity`, `WorkspaceIdentity`) | identity value types | `:domain` `ConversationId`, `ProviderId`, `WorkspaceId` | |
| `Conversation.swift` | `Conversation` aggregate, `titleOrigin`, auto-title, rename, history ownership | `:domain` `Conversation` | C-02/C-03/C-04 |
| `Message.swift` | `Message`, `MessageRole`, attachments on message | `:domain` `Message`, `MessageRole`, `MessageAttachment` | |
| `Attachment.swift` | `MessageAttachment` value | `:domain` `MessageAttachment` | |
| `Workspace.swift` | `Workspace` aggregate | `:domain` `Workspace` | |
| `Provider.swift` | `Provider` aggregate, `ProviderConnection`, `ProviderState`, `ProviderMetadata` | `:domain` `Provider`, `ProviderConnection`, `ProviderState` | |
| `ProviderAPIKind.swift` | `ProviderAPIKind` | `:domain` `ProviderApiKind` | P-04 |
| `ProviderModelSelection.swift` | `ProviderModelSelection` | `:domain` `ProviderModelSelection` | **G-01 vocabulary** |
| `ModelReference.swift`, `ModelDescriptor.swift` | model value types | `:domain` `ModelReference`, `ModelDescriptor` | |
| `ProviderCapabilities.swift`, `ProviderLimits.swift` | capability/limit metadata | `:domain` `ProviderCapabilities`, `ProviderLimits` | P-11, GEN-10 |
| `Credential.swift`, `CredentialReference.swift` | credential + reference | `:domain` `Credential`, `CredentialReference` | P-05 |
| `Capability.swift`, `CapabilityContract.swift`, `CapabilityError.swift` | capability surfaces + errors | `:domain` capability interfaces + `CapabilityError` | P-11 |
| `ConversationRepository.swift`, `WorkspaceRepository.swift`, `ProviderRepository.swift`, `ConfigurationRepository.swift` | repository contracts | `:domain` interfaces (`ConversationRepository`, etc.) | |
| `CredentialStorageProtocol.swift` | credential storage contract | `:domain` `CredentialStorage` | |
| `Configuration*.swift` (Key, Level, Value, Policy, Protocol, Repository) | configuration contracts | `:domain` `ConfigurationKey`, `ConfigurationValue`, `ConfigurationRepository` | |
| `ProviderSelectionService.swift`, `ProviderSelectionPolicy.swift` | selection service + policy | `:domain` `ProviderSelectionService` | P-09 |
| `ProviderLifecycleService.swift` | ready-provider tracking | `:domain` `ProviderLifecycleService` | |
| `StreamingRequest.swift`, `StreamingUpdate.swift`, `StreamingState.swift`, `StreamingContract` (in CapabilityContract) | streaming value model | `:domain` `StreamingUpdate` (sealed), `StreamingState` | GEN-02, GEN-12 |
| `TextGenerationRequest.swift`, `TextGenerationResponse.swift`, `ConversationRequest.swift`, `ConversationResponse.swift` | generation contracts | `:domain` `TextGenerationRequest`/`Response` | GEN-01 |
| `CapabilityRequestIdentity.swift` | request identity | `:domain` `CapabilityRequestId` | GEN-19 |
| `RepositoryError.swift`, `ProviderDiscoveryError.swift` | error taxonomy | `:domain` `RepositoryError`, `ProviderDiscoveryError` | E-11 |
| `OmniaDomain.swift` | export hub | `:domain` module (no file equivalent) | |

### 2.3 `OmniaInfrastructure` → `:data`

| Swift file | Key types | Android target (proposed) | Notes |
| --- | --- | --- | --- |
| `JSONDocumentStore.swift` | `JSONDocumentStore` | `:data` `JsonDocumentStore` | per-aggregate namespaces, lazy dirs |
| `FileWorkspaceRepository.swift`, `FileConversationRepository.swift`, `FileProviderRepository.swift`, `FileConfigurationRepository.swift` | file repositories | `:data` `FileWorkspaceRepository`, etc. | |
| `*Serializer.swift` (Workspace, Conversation, Provider, Configuration) | stable serializers | `:data` versioned serializers (kotlinx.serialization) | E-12 |
| `SecureCredentialStorage.swift`, `KeychainCredentialStorageBackend.swift`, `InMemoryCredentialStorageBackend.swift` | credential storage | `:data` `AndroidKeystoreCredentialStorage` + `InMemoryCredentialStorage` (tests) | P-05 |
| `ProviderTransport.swift`, `URLSessionProviderTransport.swift` | transport seam + URLSession impl | `:data` `ProviderTransport` + OkHttp/Ktor impl | Network layer |
| `OpenAICompatibleClient.swift`, `ChatCompletionDTOs.swift` | OpenAI-compatible client + DTOs | `:data` `OpenAiCompatibleClient` + DTOs | P-02 |
| `GeminiClient.swift`, `GeminiContentDTOs.swift`, `GeminiMapping.swift`, `GeminiProviderAdapter.swift`, `GeminiProviderInspector.swift` | Gemini client/mapping/adapter/inspector | `:data` `GeminiClient`, `GeminiMapping`, `GeminiProviderAdapter`, `GeminiProviderInspector` | P-03, P-07 |
| `OpenAICompatibleProviderInspector.swift`, `ProviderInspector.swift`, `ModelDiscoveryDTOs.swift` | discovery | `:data` `ProviderInspector`, `ModelDiscovery` | P-07, P-08 |
| `ProviderAdapter.swift`, `CapabilityMapping.swift`, `ProviderErrorMapping.swift`, `ProviderMapping` | adapter + mapping + error translation | `:data` `ProviderAdapter`, `CapabilityMapping`, `ProviderErrorMapping` | P-02/P-03, E-01…E-10 |
| `SSEDecoder.swift` | SSE streaming decoder | `:data` `SseDecoder` | GEN-02 |
| `FileAttachmentStorage.swift`, `AttachmentContentProcessor.swift` | attachment persistence/processing | `:data` `FileAttachmentStorage` | GEN-05…GEN-09 |
| `OmniaInfrastructure.swift` | export hub | `:data` module | |

### 2.4 `OmniaApplication` → `:app`

| Swift file | Key types | Android target (proposed) | Notes |
| --- | --- | --- | --- |
| `ConversationService.swift` | conversation lifecycle service | `:app` `ConversationService` | C-01 |
| `WorkspaceService.swift` | workspace service | `:app` `WorkspaceService` | |
| `ProviderConnectionService.swift` | provider CRUD service | `:app` `ProviderConnectionService` | P-01 |
| `ConfigurationService.swift` | typed config service | `:app` `ConfigurationService` | |
| `SendMessageRequest.swift` | `SendMessageRequest` | `:app` `SendMessageRequest(conversation, message, modelSelection)` | **G-01** |
| `SendMessageUseCase.swift` | send-message flow (append → stream → persist) | `:app` `SendMessageUseCase` | GEN-01…GEN-04 |
| `AttachmentImport.swift`, `AttachmentService.swift`, `AttachmentService+Resolution.swift` | attachment import/resolution/limits | `:app` `AttachmentImporter`, `AttachmentService` | GEN-05…GEN-11 |
| `ConversationDraftService.swift` | draft store | `:app` `ConversationDraftService` | C-08 |
| `DataManagementService.swift` | Clear Data orchestration | `:app` `DataManagementService` | S-05 |
| `ProviderModelService.swift` | model + default-selection service | `:app` `ProviderModelService` | P-07/P-08/P-09 |
| `ProviderValidationService.swift` | Test Connection orchestration | `:app` `ProviderValidationService` | P-06 |
| `ConfigureProviderRequest.swift`, `ProviderUpdateRequest.swift` | request values | `:app` `ConfigureProviderRequest`, `ProviderUpdateRequest` | P-01 |
| `ApplicationValidationError.swift` | validation errors | `:app` `ApplicationValidationError` | |
| `OmniaApplication.swift` | export hub | `:app` module | |

### 2.5 `OmniaPresentation` → `:presentation`

| Swift file | Key types | Android target (proposed) | Notes |
| --- | --- | --- | --- |
| `RootView.swift`, `SideMenuView.swift` | shell + drawer | `:presentation` `RootScreen` + `SideMenu` | S-12, A-02 |
| `ConversationListView.swift` | conversation list screen | `:presentation` `ConversationListScreen` | C-05/C-06/C-07 |
| `ConversationScreenView.swift` | chat screen + composer | `:presentation` `ConversationScreen` | GEN-12…GEN-17 |
| `ProvidersView.swift`, `ProviderConnectionFormView.swift` | providers list + form | `:presentation` `ProvidersScreen`, `ProviderConnectionFormScreen` | P-01, P-06 |
| `SettingsView.swift`, `AboutView.swift` | settings/about | `:presentation` `SettingsScreen`, `AboutScreen` | S-03/S-04 |
| `EmptyStateView.swift`, `ErrorBannerView.swift`, `StatusIndicator.swift`, `SectionHeader.swift` | shared components | `:presentation` components | |
| `ConversationListState.swift`, `ConversationScreenState.swift`, `SettingsState.swift`, `NavigationState.swift` | state models | `:presentation` State classes (StateFlow) | |
| `ConversationListSurface.swift`, `ConversationScreenSurface.swift`, `SettingsSurface.swift`, `NavigationSurface.swift` | intent→effect translation | `:presentation` `Surface` interfaces | |
| `ConversationGenerationCoordinator.swift` | keyed coordinator + identity guard | `:presentation` `ConversationGenerationCoordinator` | GEN-19 |
| `ConversationListItem.swift`, `MessagePresentation.swift`, `ProviderConnectionListItem.swift` | render-ready models | `:presentation` data classes | |
| `AttachmentPickerPresentationState.swift` | picker staging state | `:presentation` `AttachmentPickerState` | GEN-06 |
| `MarkdownContent.swift`, `MarkdownView.swift` | markdown parse + render | `:presentation` `MarkdownContent` + `MarkdownView` | M-01…M-08 |
| `DesignTokens.swift`, `OmniaBackground.swift`, `OmniaButton.swift`, `OmniaCard.swift`, `OmniaIconButton.swift` | design system | `:presentation` `DesignTokens`, MaterialTheme mapping | |
| `Localized.swift` | localization (95 keys) | `:presentation` string resources + `Localized` | X-02 |
| `AppVersionInfo.swift` | version info | `:presentation` `AppVersionInfo` | S-04 |
| `OmniaPresentation.swift` | export hub | `:presentation` module | |

### 2.6 `OmniaApp` → `:app-shell`

| Swift file | Key types | Android target (proposed) | Notes |
| --- | --- | --- | --- |
| `CompositionRoot.swift` | manual composition | `:app-shell` `AppGraph` / `CompositionRoot` | |
| `StorageLayout.swift` | storage root + subdir layout | `:app-shell` `StorageLayout` (filesDir-based) | |
| `ProviderAdapterBinding.swift` | family-routed binding | `:app-shell` `ProviderAdapterBinding` | P-04 |
| `FirstRunBootstrap.swift` | idempotent first-run | `:app-shell` `FirstRunBootstrap` | |
| `AppEdgeConstants.swift` | edge constants | `:app-shell` `AppEdgeConstants` | G-07 |
| `AppLaunch.swift`, `LaunchFailureCopy.swift` | launch sequence + failure copy | `:app-shell` `AppLaunch`, `LaunchFailureCopy` | |
| `OmniaApp.swift` | app struct | `:app-shell` `Application` + `MainActivity` | |

## 3. Owners (who owns what)

| Module | Owner | Primary responsibility |
| --- | --- | --- |
| `:core` | Foundation | Identifiers, clock, cancellation, environment, lifecycle, logging/redaction, semantic version |
| `:domain` | Domain | Aggregates, contracts, selection vocabulary, error taxonomy, capabilities/limits |
| `:data` | Infrastructure | Persistence, credential storage, transports, adapters, mapping, error translation, discovery/cache |
| `:app` | Application | Services/use cases, attachments, drafts, data management, boundary validation |
| `:presentation` | Presentation | Screens, state, surfaces, coordinator, Markdown, tokens, localization, accessibility |
| `:app-shell` | App edge | Composition root, bootstrap, constants, launch, adapter binding, platform entry |

*Cross-module invariants (duplicate protection, selection vocabulary, persistence strictness) are owned jointly by the module pair that implements them and are enforced by the tests listed in `ANDROID_TEST_MATRIX.md`.*

## 4. What is deliberately not mapped (see `ANDROID_ARCHITECTURE.md` §4)

Actors/`AsyncThrowingStream`, SwiftUI/SwiftPM mechanics, Keychain/PhotosUI/UTType specifics, property wrappers — replaced by Android equivalents, never copied as behavior.
