# Design → Code Parity Matrix

| | |
| --- | --- |
| **Document** | DESIGN_PARITY_MATRIX |
| **Date** | 2026-08-16 |
| **Scope** | Frozen design API contracts (DES-001..DES-013, architecture ARC-001..ARC-009, UI design system, `V1_DEVICE_TEST_CHECKLIST`) vs. the six Swift packages (`OmniaFoundation`, `OmniaDomain`, `OmniaApplication`, `OmniaInfrastructure`, `OmniaPresentation`, `OmniaApp`). |
| **Method** | Design specs and UI/acceptance docs read in full; code audited per layer (source + tests); environment verified with a clean Linux `swift build` + `swift test` run in Docker (Swift 6.0.3, x86_64-unknown-linux-gnu). |
| **Verification** | Build: PASS (all 7 targets). Tests: PASS (0 failures across 1,303 executed tests). See §7. |
| **Statuses** | `PASS` — requirement implemented with direct evidence. `PARTIAL` — implemented with caveats / partial surface. `GAP` — requirement not met. `UNVERIFIED` — no direct code evidence (typically a device/interaction test). `OUT-OF-SCOPE` — explicitly deferred by the spec. |

## 1. Purpose

A requirement-by-requirement cross-check that the ratified design contracts are realized in code, so that a deviation from the frozen surface is visible, triaged, and resolved — "a deviation from that surface is a defect and is resolved by correcting the implementation, never by silently changing the surface" (DES-011 §7).

## 2. Legend

- Evidence paths are relative to the repo root (`Packages/<Package>/Sources/...`).
- Each layer table groups requirements by the spec that owns them.
- Test counts per package (Linux run, §7): Foundation 136, Domain 347, Application 238, Infrastructure 293, Presentation 233, App 55, root 1.

---

## 3. Foundation (DES-001..008)

| Spec | Requirement | Code evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| DES-002 | Typed, fresh identity primitive with stable canonical serialized form and strict restoration | `OmniaFoundation/Sources/OmniaFoundation/Identifier.swift` — `Identifier<Kind>: Hashable, Sendable, Codable`; `init()`, `init?(restoring:)`, `canonicalString`; Codable single-value; `debugDescription` ≠ canonical | PASS | `Identifier()` wraps a fresh `UUID`. Restoration validates strict canonical UUID format. 20 tests. |
| DES-003 | Clock abstraction, injectable, testable; `Instant` opaque monotonic value | `Clock.swift` — `Clock` protocol (`now`, `measure`, `sleep(for:)`, `sleep(until:)`) + `Instant` | PASS | No concrete clock in package; tests define `TestClock` (18 tests). |
| DES-008 | Cooperative, injectable cancellation; distinct from failure | `Cancellation.swift` — `CancellationObservation`, `CancellationSource`, `CancelledOutcome (.cancelled/.failed)` | PASS | One-way, idempotent, never revoked; no global state. 17 tests. |
| DES-005 | Logging protocol with context, metadata, redaction | `Logger.swift` — `Logger`, `LogEvent`, `LogContext`, `LogMetadata`, `LogLevel` (7 levels), `Sensitive` (description/debugDescription always `<redacted>`) | PASS | Timestamps come from a `Clock`, never system time. 17 tests. |
| DES-006 | Environment as deterministic facts, no ambient global | `Environment.swift` — `Environment`, `Platform`, `PlatformFamily`, `ExecutionMode`, `EnvironmentCapability.isAvailable(_:)` | PASS | Composition-root constructed; no `currentEnvironment`. 29 tests. |
| DES-007 | Lifecycle state machine with legal transitions, thread-safe | `Lifecycle.swift` — `Lifecycle<State>`, `LifecycleState`, `LifecycleTransition`, `LifecycleEvent`, `LifecycleObserver` | PASS | Rejected transitions return `nil`, no event. Observers after state change. 22 tests. |
| DES-001 | Error abort contract (`isUnrecoverable`/`Description`-style) | **No error type in Foundation.** Only `DecodingError.dataCorruptedError` (Identifier decode) and throwing `Clock.sleep/measure` signatures. | UNVERIFIED | Needs confirmation against the current DES-001 text; if DES-001 mandates an abort contract this is a gap. Not exercised by any package test. |
| — | Semantic versioning value type | `SemanticVersion.swift` — major/minor/patch, Comparable, Codable-adjacent | PASS | 13 tests. |

---

## 4. Domain (DES-009)

| Spec | Requirement | Code evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| §3.1 | Identity markers for conversation, provider, workspace (`Identifier<Kind>`) | `ConversationIdentity`, `ProviderIdentity`, `WorkspaceIdentity` in `OmniaDomain` | PASS | Verified by Application-layer usage (`Identifier(restoring:)` in bootstrap, keyed state maps). |
| §3.1 | Immutable, `Equatable`/`Sendable` value types in Domain vocabulary | `Message`, `MessageRole` (system/user/assistant), `MessageAttachment` (`OmniaDomain/Attachment.swift` — `identity`, `kind`, `source`, `byteCount`), `ModelReference`, `ProviderModelSelection`, `ProviderState`, `ProviderAPIKind` (`.openAICompatible` default, `.gemini`), `ProviderCapabilities`, `ProviderLimits`, `SemanticVersion`, `CredentialReference`, `Credential`, `ProviderConnection` | PASS | Confirmed at type level by Application/Presentation/App usage; attachment limit values live at the Application boundary (below). |
| §3.2 | Conversation aggregate owns its history; streaming view is the Domain stream, not a redefined type | `Conversation` aggregate; `StreamingUpdate` (`contentDelta(partialContent:)` / `completion(message:)` / `interruption(partialContent:)`) | PASS | Completion event carries the assembled assistant `Message`. |
| §3.2 | Auto-title from first user message; user title always wins | `OmniaDomain/Conversation.swift:26-153` — `titleOrigin` (`ConversationTitleOrigin` `.automatic/.user`), `rename(to:)` (normalized, 160-char cap), auto-title prefix 80; `titleOrigin == .user` is never overwritten by derivation | PASS | Direct evidence. |
| §3.4 | Repository contracts (conversation, workspace, provider, configuration) | `ConversationRepository`, `WorkspaceRepository`, `ProviderRepository`, `ConfigurationRepository` protocols | PASS | Implemented by Infrastructure (§5). |
| §3.5 | Capability contracts: text generation, conversation, streaming | `TextGenerationContract`, `ConversationContract`, `StreamingContract` | PASS | Conformed by Infrastructure adapters and App `ProviderAdapterBinding`. |
| §3.5 | Streaming lifecycle: deltas with request identity → completion with assembled message; interruption preserves partial content | `StreamingUpdate` + `CapabilityError.streamingInterrupted(partialContent:)`; enforced in Infrastructure (§5) and Application (§6) | PASS | Cancellation ends as interruption, never a lost response. |
| §3.6 | Configuration vocabulary: typed `ConfigurationKey<Value>`, `ConfigurationLevel` (providerSettings / workspaceOverride / globalDefault / capabilityPreference), deterministic resolution order | `ConfigurationKey`, `ConfigurationLevel`, `ConfigurationRepository` | PASS | Levels `.providerSettings`, `.workspaceOverride`, `.globalDefault` observed in App/Presentation; resolution order exercised by ConfigurationService tests. |
| §3.2 | Provider selection service honoring ARC-004 priority (explicit user selection → workspace/capability preference → deterministic ready-provider order); failed selection → `CapabilityError.providerUnavailable`, never silent | `ProviderSelectionService`; `ProviderLifecycleService` (ready-provider set) | PASS | App `ProviderAdapterBinding.readyProvidersOffering(_:)` re-applies the same deterministic canonical-identity order and `CapabilityError` failures (see §7 row). |
| §3.9/§3.11 | Credential storage by reference; `CredentialStorageProtocol` | `CredentialStorageProtocol`; `CredentialStorageError` (`.credentialNotFound`, `.storageUnavailable`) | PASS | Secrets never serialized; Infrastructure implements backends (§5). |
| §3.7 | Typed errors: `RepositoryError`, `CapabilityError`, `CredentialStorageError`, `ConversationStreamError`, `ProviderConnectionTestError` | Present in `OmniaDomain`; surfaced unwrapped across all layers | PASS | `CapabilityError` includes `providerUnavailable`, `invalidRequest`, `invalidResponse`, `streamingInterrupted(partialContent:)`, `modelUnavailable(model:)`. |
| §3.11 | API-kind value type, default OpenAI-compatible, persists via Codable | `ProviderAPIKind` (Codable Domain value) | PASS | Used by `ProviderAdapterBinding` and the connection form. |

---

## 5. Infrastructure (DES-010)

| Spec | Requirement | Code evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| §3.1/3.2 | File-based JSON document store; one repository per aggregate; save/load/delete/list by identity | `FileWorkspaceRepository`, `FileConversationRepository`, `FileProviderRepository`, `FileConfigurationRepository` over an internal file document-store engine | PASS | Storage engine internal to package; directories one per repository (App layout §8). |
| §3.3 | Aggregate serializers/DTOs internal; round-trip exactly; never emit credentials | Internal DTOs + serializers for Workspace, Conversation (with history), Provider, configuration | PASS | Serialization internal; credential references serialized, never secrets. |
| §3.4 | Secure credential storage: Keychain (Apple), in-memory (Linux/tests); backend seam replaceable | `SecureCredentialStorage` | PASS | Contract failures honored exactly; in-memory backend used on Linux build/tests. |
| §3.5 | `ProviderTransport` seam isolates HTTP; internal request/response DTOs | `ProviderTransport` protocol; `ChatCompletionRequest/Response/Chunk`; `GeminiContentDTOs` (`GenerateContentRequest/Response`, `GeminiModelsResponse`) | PASS | Clients testable without a network. |
| §3.5/3.6 | OpenAI-compatible client + adapter: text generation, conversation, streaming | `OpenAICompatibleProviderAdapter` (TextGeneration/Conversation/Streaming) | PASS | Mapping: prompt→single user message; history→ordered messages; `stream:true` for streaming; chunk deltas→`contentDelta`, end→`completion`. |
| §3.10 | Gemini client + adapter + inspector | `GeminiClient` (generateContent, `:streamGenerateContent?alt=sse`, models list, availability probe), `GeminiProviderAdapter`, `GeminiProviderInspector` (`discoverModels()`, `testConnection(model:)` with `ProviderConnectionTestError.modelUnavailable`) | PASS | Auth only via `x-goog-api-key` from stored credential by reference; never in URLs/logs/metadata. Candidate credentials never persisted (non-persisting in-memory storage for the form). |
| §3.9.3 | Error translation: credential failure → `CredentialStorageError`; transport → `providerUnavailable`/`invalidRequest`/`invalidResponse`; streaming failure → `streamingInterrupted(partialContent:)` | Adapter/mapping error translation (`GeminiMapping` + OpenAI translation) | PASS | Nothing fails silently; no raw storage/transport error crosses the boundary. |
| §3.9.4 | Streaming ends in completion or interruption; cancelled stream → interruption with preserved partial | Streaming lifecycle in adapters | PASS | Verified by Infrastructure tests and Application interruption tests. |
| §3.10 | Model discovery from real provider catalog; recorded model absent → `modelUnavailable` | `GeminiProviderInspector` | PASS | Never fabricated data. |

---

## 6. Application (DES-011)

| Spec | Requirement | Code evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| §3.1 | Application value objects immutable, `Equatable`/`Sendable`, no business logic, Domain vocabulary only | `SendMessageRequest`, `ConfigureProviderRequest`, `ProviderUpdateRequest` | PASS | **Drift noted below on `SendMessageRequest` selection vocabulary.** |
| §3.1 | `SendMessageRequest` selection vocabulary matches spec | Spec (DES-011 §3.1, DES-012 provider-selection intent): `userSelection: ProviderIdentity?`, `workspacePreference: ProviderIdentity?`, `capabilityPreference: ProviderIdentity?`. **Code:** `SendMessageRequest(conversation:message:modelSelection:)` with `ProviderModelSelection` (provider+model pair). | PARTIAL | Functionally equivalent (explicit selection honored, non-selectable skipped and announced), but the **contract surface differs from the frozen text**. Recommendation: revise DES-011 §3.1 / DES-012 to the `modelSelection` vocabulary (per UX audit V2), or restore the spec's fields. See Gap G-01. |
| §3.2 | `ConversationService`: create, create-in-workspace, get by identity, list in workspace, delete, rename | `OmniaApplication/ConversationService.swift` (rename at :118-131 — persists user title without changing history; empty title rejected) | PASS | Rename path directly exercised by Presentation `onRename` and tests. |
| §3.3 | `SendMessageUseCase.send`: append + persist user message **before** stream; deliver Domain `StreamingUpdate` events incrementally; append + persist assembled assistant message on completion (never loses the reply) | `SendMessageUseCase`/`MessageStore`/`SendMessageFlow` | PASS | Completion persists; interruption preserves partial + marks interrupted; resume carries partial forward, appends no user message, rejects non-stored/non-interrupted. 238 Application tests incl. interruption/resume. |
| §3.3 | Selection/capability/credential failures surface as the exact Domain errors, never wrapped | `SendMessageUseCase` paths | PASS | `CapabilityError.providerUnavailable` on failed selection; `CredentialStorageError` on credential resolution. |
| §3.4 | `ProviderConnectionService`: configure/update/remove/all; credential stored only by reference; remove also removes credential + model key + API-kind key | `ProviderConnectionService` | PASS | Credential never enters connection/repository/configuration beyond the pointer. |
| §3.9 | Endpoint surface: validate non-empty absolute http(s) URL; reject malformed before storage; never enters aggregate | `ProviderConnectionService.endpointKey/updateEndpoint/endpoint` + boundary validation | PASS | Endpoint is not a credential. |
| §3.10 | Model surface: non-empty trimmed value when given; nil records nothing; typed key | `ProviderConnectionService.modelKey/updateModel/model` | PASS | Model never enters `ConfigureProviderRequest`. |
| §3.11 | API-kind surface: idempotent update; unrecorded resolves to `ProviderAPIKind.default` | `ProviderConnectionService.apiKindKey/updateAPIKind/apiKind` | PASS | Backward compatible for pre-kind connections. |
| §3.5 | `ConfigurationService`: store/value/resolved/remove, typed values per level, deterministic resolution order | `ConfigurationService` | PASS | Resolution order exercised by tests. |
| §3.6 | Boundary validation with typed `ApplicationValidationError` before any domain op | `ApplicationValidationError` (empty workspace name, malformed endpoint/model, etc.) | PASS | |
| §3.8 | `WorkspaceService`: create (empty name rejected), get, add conversation/provider; `createConversation(in:)` atomic (missing workspace fails before create) | `WorkspaceService`, `ConversationService.createConversation(in:)` | PASS | Attach uses aggregate value-typed `adding(conversation:)/adding(provider:)`. |
| §3.1 | Attachments: bounded import, explicit limits, per-file/total/count enforcement, revalidation on provider/model change | `OmniaApplication/AttachmentImport.swift` — `AttachmentLimits` (defaults: max **8** files, **10 MB**/file, **25 MB** aggregate, **200 000** extracted chars), `AttachmentImportCandidate` (metadata-only description, bytes `<redacted>`), `PhotoAttachmentImport`; `AttachmentService`; `AttachmentError` (`photoLoadFailed`, storage, unsupported type, limits, model capability) | PASS | Presentation revalidates staged attachments on model change (RootView `validateAttachments`). Limits surfaced to UI (`ConversationScreenView` reads `AttachmentLimits().maximumFileBytes`). |

---

## 7. Presentation (DES-012)

| Spec | Requirement | Code evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| §3.1 | Value types: `ConversationListItem`, `MessagePresentation`, `MarkdownContent`, `ProviderConnectionListItem`; immutable, `Equatable`/`Sendable`, no credentials | `OmniaPresentation/ConversationListItem.swift`, `MessagePresentation.swift`, `MarkdownContent.swift`, `ProviderConnectionListItem.swift` | PASS | |
| §3.2 | State types: `ConversationListState`, `ConversationScreenState`, `SettingsState`, `NavigationState`; `ModelEditing`; `Editing.currentAPIKind` | Corresponding files; `ConversationScreenState` carries messages, draft, `draftAttachments`, `attachmentIssue`, `streamingCondition` (.thinking/.active/.complete/.interrupted), `failure`, `providerSelection` | PASS | Streaming conditions mirror Domain stream states without redefinition; interruption preserves partial content (`ConversationGenerationCoordinator.interruptedState`). |
| §3.3 | List surface: create/select/delete/rename over `ConversationService`; create-in-workspace; list never diverges from create on workspace | `ConversationListSurface`; `RootView.createConversation()` uses `surface.conversationList.create(in: workspace)` and loads membership | PASS | |
| §3.3.1 | `MarkdownContent` segmentation deterministic, platform-independent; text/code-block only; whitespace preserved | `MarkdownContent.swift` — block enum (`paragraph`, `heading`, `unorderedListItem`, `orderedListItem`, `blockQuote`, `horizontalRule`, `codeBlock(content:language:)`); fenced-code parser (opening/closing fence, language id ≤32 chars, sanitized) | PASS | Rendered on Linux-tested logic; `MarkdownContentTests` in Presentation suite (233 tests, all pass). |
| §3.3.1 | Native Apple rendering only; code blocks monospaced + distinct background + preserved whitespace; **no** language-aware coloring | `MarkdownView.swift` — `AttributedString(markdown:)` for prose; code block: system monospaced body, platform background (`secondarySystemGroupedBackground`/`textBackgroundColor`), preserved whitespace, 12pt radius; comment at :18 confirms no language-aware syntax coloring | PASS | Direct evidence. |
| §3.3.1 | Safe links: only http/https/mailto links render as links | `MarkdownView.attributed(_:)` (:148-159) strips unsafe link schemes | PASS | Direct evidence. |
| §3.3.1 | Fenced code shows language label; long code scrolls horizontally; Copy Code works | `MarkdownView.codeBlock` (:100-136) — `Text(language ?? Localized.code)` header, horizontal `ScrollView`, Copy Code button with "Copied" state | PASS | Direct evidence. |
| §3.3 | Screen surface renders `StreamingUpdate` events incrementally; never blocks; auto-scrolls | `ConversationScreenView.swift` — `autoScrollAnchor` (:111), `ScrollViewReader` (:182), `.onChange(of: autoScrollAnchor)` → `scrollToLatest` (:1119-1129); jump-to-latest affordance (:1142) | PASS | |
| §3.3 | Provider selection intent; non-selectable selection skipped and announced, never silent | `ConversationScreenState.ProviderSelection` (composed by shell); `ConversationScreenView` announces the applied selection | PASS | See G-01 for the vocabulary drift. |
| §3.4 | Settings surface: provider connections, config, connection-form/endpoint/model/API-kind edits; edit pre-filled, single field, failed update keeps editor open with input retained | `SettingsSurface`, `SettingsView`, `ProvidersView`, `ProviderConnectionFormView` (API-kind picker at :194) | PASS | Endpoint/model/API-kind edits handled by App shell intents; failed updates keep form open (state-driven). |
| §3.5 | Navigation model value-typed routes; platform-native navigation; shell routes list→conversation/providers/settings/about | `NavigationState` (`.conversationList`, `.conversationScreen`, `.providers`, `.settings`, `.about`); `NavigationSurface`; `RootView` hosts via NavigationStack | PASS | |
| §3.6 | Composition seam: surfaces receive collaborators via public initializers; no Composition Root / DI in package | `ConversationListSurface(service:)`, `ConversationScreenSurface(useCase:)`, `SettingsSurface(...)`, `NavigationSurface` | PASS | `OmniaPresentation/Package.swift` depends only on OmniaApplication + OmniaFoundation (no Domain/Infra edge). |
| §3.7 | Platform-independent logic builds/tests on Linux; SwiftUI view layer behind `#if canImport(SwiftUI)`; views not exercised by Linux tests | All views gated by `#if canImport(SwiftUI)`; `MarkdownContent`/state types Linux-tested | PASS | Confirmed by Linux test run (§9): Presentation 233/233 pass. |
| A11y | Accessibility labels/actions; VoiceOver streaming lifecycle announcements | `ConversationScreenView` — `announceStreamingTransition` posts `.announcement` started/completed/interrupted (UX audit A4; :1207-1226); `ConversationListView` — combined rows + `accessibilityAction` rename/delete; `StatusIndicator`, `ErrorBannerView`, `EmptyStateView` labels | PASS | |
| A11y | Reduced motion | No `accessibilityReduceMotion` handling found. `OmniaTheme.Motion.drawer` animation only. | UNVERIFIED | Native SwiftUI does not auto-disable custom spring animations; device test required. Gap G-02. |
| A11y | High contrast, Dynamic Type no-clipping at accessibility sizes | No explicit handling; SwiftUI `Text` scales by default; bubble width capped at 80% of readable width (`MessageBubbleWidthPolicy`), long content wraps. | UNVERIFIED | Device-test dependent (V1 checklist items). |
| UX | Per-conversation provider/model survives relaunch; unsent draft survives navigation/relaunch | `RootView` — `conversationModelSelections` + persisted `Conversation.modelSelection`; `conversationDrafts` + `surface.drafts` (save/restore on leave/reopen) | PASS | Draft writes debounced per conversation (`draftPersistenceTasks`), awaited before destructive boundaries. |
| UX | Day grouping (Today / Yesterday / Previous 7 Days / Older / Future) | `ConversationListState.sections()`; `ConversationListView.groupTitle` (:212-220); search keeps activity groups | PASS | |
| UX | Search filters rows by title/preview | `ConversationListView.filteredItems` (:284-291), no-results state (:381-389) | PASS | |
| UX | Swipe/delete: full swipe never deletes; explicit confirm; system dialog is the a11y path | `ConversationSwipeBehavior` (geometry/settle rules), `ConversationSwipeRevealRow`, `.confirmationDialog` before `onDelete` (:96-113) | PASS | |
| UX | Navigation drawer, 292pt, menu rows, dark-mode toggle | `SideMenuView.swift:123` `.frame(width: 292)`; `RootView` drawer (dim backdrop + slide-in) | PASS | |
| UX | Dark mode: default dark, toggle in drawer + Settings, persisted at workspace level, restored at launch | `RootView` — `darkModeKey = ConfigurationKey<Bool>("appearance.darkMode")` (:128), stored at `.workspaceOverride` (:508), restored via `resolveDarkModeAppearance` | PASS | |
| UX | Settings sections: Configuration / Appearance (Dark Mode row) / About | `SettingsView.swift` (:141 Configuration, :162 Appearance/Dark Mode, :184 About) | PASS | |
| UX | Streaming states distinct: Thinking / Streaming / completed / interrupted; Thinking/Streaming cards | `ConversationScreenView` thinking/streaming/interrupted rows + `StreamingAnnouncement` copy; `Localized` keys | PASS | |
| L10n | All user-visible strings localized, no hardcoded copy | `Localized.swift` (95 keys); no literal user-facing strings in views | PASS | |
| UX | Empty states: no-provider → Add Provider; no conversations → Start new conversation; loading distinct | `ConversationListView.emptyState` + `showsProviderSetup` (:391-409); `RootView.loadingState` | PASS | |
| — | Apple-only shell views | `RootView`, `ConversationListView`, `ConversationScreenView`, `SideMenuView`, `AboutView`, `SettingsView`, `ProvidersView`, `ProviderConnectionFormView`, `MarkdownView`, `StatusIndicator`, `SectionHeader`, `ErrorBannerView`, `EmptyStateView`, `OmniaCard/Button/IconButton/Background`, `DesignTokens`, `AppVersionInfo` | PASS | |

---

## 8. App Edge (DES-013)

| Spec | Requirement | Code evidence | Status | Notes |
| --- | --- | --- | --- | --- |
| §3.1 | Composition Root: ordered construction (storage root → repositories → credential storage → services → adapter binding → surfaces → RootView); hand-written; sole Infrastructure reference point | `OmniaApp/Sources/OmniaApp/CompositionRoot.swift` | PASS | One directory per repository; Clear Data owns the app credential namespace (:314-316); drafts delivered via `conversationDraftService` (:369). |
| §3.2 | Storage layout: Application Support + stable app-named subdir; per-repository namespaces; lazy dir creation; credentials never in files | `StorageLayout.platformRoot()` (`.applicationSupportDirectory` + `AppEdgeConstants.storageRootDirectoryName = "Omnia"`); `AppEdgeConstants.swift` | PASS | Root derived once, CWD-independent, Linux-testable. |
| §3.3 | Runtime adapter binding: resolve endpoint/credential/model/API-kind from provider-settings typed keys; family-routed adapter (OpenAI-compatible vs Gemini); unrecorded kind → default; incomplete inputs → unavailable via discovery channel, never launch failure; shared `preferredModels` with selection | `ProviderAdapterBinding.swift` — reads `ProviderConnectionService.endpointKey/credentialReferenceKey/apiKindKey` at `.providerSettings`; family switch (:68-84); `adapter(for:model:)` (:156-194) throws `CapabilityError.providerUnavailable`/`modelUnavailable`; `readyProvidersOffering` in canonical order (:199-209); `preferredModels` closure | PASS | Strong direct evidence; adapter bound per-request, never at composition. |
| §3.3 | `preferredModels`: recorded model or `AppEdgeConstants.defaultModelName` fallback | `AppEdgeConstants.defaultModelName = "omnia-coding"` (legacy fallback; production catalogs come from discovery/cache/manual) | PASS | |
| §3.4 | First-run bootstrap: resolve default workspace from global-defaults key; create via `WorkspaceService.createWorkspace(named:)` when absent; idempotent; silent (no onboarding) | `FirstRunBootstrap.resolve()` — `app.defaultWorkspaceIdentity` at `.globalDefault`; re-records identity; never constructs aggregate | PASS | Runs on Linux build environment. |
| §3.5 | Shell: launch sequence Launch → Compose → Bootstrap → Build surface → Host; owns session state (workspace, route); entry point isolated behind platform availability | `AppLaunch`, `OmniaApp.swift`, `OmniaAppExecutable.swift`; `RootView(workspace: RootView.workspace)`; `NavigationState` at shell | PASS | |
| §3.5 | Shell drives streaming with cancellation + partial-content preservation | `RootView` — `generationCoordinator.cancel`, interrupted presentation; `ConversationGenerationCoordinator` (`cancel`/`discard`/`discardAll`) | PASS | Keyed by conversation: navigation changes only observation, never provider work; deletion and Clear Data await cancellation before removing data. |
| §3.5 | Launch failure copy; app-edge constants | `LaunchFailureCopy.swift`, `AppEdgeConstants.swift` | PASS | |
| — | About version/build reported | `AppVersionInfo` (version/build read from bundle/edge) | PASS | |

---

## 9. Cross-cutting behaviors (UX audits, product, architecture rules)

| Requirement | Evidence | Status |
| --- | --- | --- |
| ARC-002: layers never define contracts they orchestrate; dependency direction Foundation ← Domain ← Application ← Presentation, Infrastructure ← Application-composed at edge | `Package.swift` manifests: Domain→Foundation; Application→Domain+Foundation; Infrastructure→Domain+Foundation; Presentation→Application+Foundation; App→all five; root umbrella→all. No Domain/Infrastructure edge from Presentation; no upward edges. | PASS |
| ARC-005: user owns data; removal paths exist; credentials isolated from application data | Delete conversation (list `onDelete` + `RootView.deleteConversation` removes attachments + draft + state), provider `remove` (also removes credential/model/API-kind keys), Clear Data (explicit confirmation + scope, purges app credential namespace), Keychain/in-memory credential storage outside the file layout | PASS |
| ARC-001 / no-silent-failure: typed errors surfaced as-is, never wrapped; no operation fails silently | All layers; `FailureCopy` maps typed errors to copy; settings/list failure surfaces | PASS |
| Streaming continuity across navigation (A→B→A, Providers/Settings/About during streaming) | `ConversationGenerationCoordinator` keyed operations; off-screen updates retained and rendered on return; no cross-conversation chunk bleed | PASS |
| Stop preserves interrupted partial; retry/continue do not duplicate the user message | `RootView.retry()` — resume carries partial content; regenerate truncates stale reply; re-send keeps history prefix; no user message appended beyond prompt | PASS |
| Keyboard dismisses correctly; unsent draft survives navigation/relaunch | Draft binding + `surface.drafts` persistence (`RootView.persistDraft/restoreDraft`) | PASS (relaunch persistence confirmed in code; relaunch is device-test) |
| Background/foreground and lock during generation | Unstructured keyed tasks continue while view unobserved; no explicit lifecycle suspension handling | UNVERIFIED (device test) |
| No credential/message/file content in logs or diagnostics | `Sensitive<Value>` redaction in Logger; `AttachmentImportCandidate.description` redacts bytes; `LogMetadata` string-only | PASS |
| Localization completeness | `Localized` (95 keys) | PASS |

---

## 10. Acceptance-criteria mapping (V1_DEVICE_TEST_CHECKLIST)

Checklist category → implementation readiness. Items marked PASS have direct code evidence; device-verification items are UNVERIFIED by necessity (they require a signed IPA on hardware).

| Category | Item | Readiness | Evidence |
| --- | --- | --- | --- |
| Install/Launch | Clean launch; no crash/blank/loop; version 1.0.0 (1) | PASS (code) / UNVERIFIED (device) | `AppLaunch`+`LaunchFailureCopy`+`AppVersionInfo`; 55 App tests pass |
| Install/Launch | Upgrade preserves data | PASS (code) | Stable serialized forms + layout; storage round-trip tests |
| Onboarding/Providers | No-provider state exposes Add Provider | PASS | `ConversationListView.emptyState` (`showsProviderSetup`) |
| Onboarding/Providers | Add Provider, Test Connection, save; edit + retest | PASS | `ProvidersView`+`ProviderConnectionFormView`; `GeminiProviderInspector`/`OpenAICompatible` test connection |
| Onboarding/Providers | API Type (OpenAI-compatible vs Gemini) offered and persists per connection | PASS | `ProviderConnectionFormView` API-kind picker; `ProviderConnectionService.apiKindKey`; `ProviderAPIKind` default |
| Onboarding/Providers | Invalid key/endpoint/model errors actionable; cancel/back recoverable | PASS | Boundary validation; form state retained on failure |
| Onboarding/Providers | Active/default provider + model coherent; per-conversation selection survives relaunch | PASS | `conversationModelSelections` + persisted `Conversation.modelSelection` + deterministic migration (`prepareModelSelection`) |
| Onboarding/Providers | Unavailable model blocks/corrects without silent redirect | PASS | `CapabilityError.modelUnavailable`; selection `isAvailable` check |
| Onboarding/Providers | Provider deletion removes its credential/reference | PASS | `ProviderConnectionService.remove` + model/API-kind key removal |
| Chat | Thinking/streaming/completed distinct | PASS | Streaming rows + announcements |
| Chat | Stop preserves interrupted partial | PASS | `generationCoordinator.cancel` → `.interrupted(partialContent:)` |
| Chat | Retry/Continue no user-message duplication | PASS | `RootView.retry/regenerate` |
| Chat | Navigate A→B→A, Providers/Settings/About during streaming; no duplicate/cross-conversation chunks | PASS | Keyed coordinator + keyed state maps |
| Chat | History + interrupted/completed state survive relaunch | PASS (code) | Persistence via use case completion/interruption; device test for relaunch |
| Attachments | Photo(s), Files picker, PDF, text document; remove staged; unsupported type validation; per-file/total/count limits; model-capability blocking; revalidation on provider/model change; history reload; deletion cleans files | PASS | `PhotoAttachmentImport`/`stageFiles`/`stage`/`remove`/`validate`; `AttachmentLimits` (8 / 10 MB / 25 MB / 200k); `AttachmentError`; `RootView.addFiles/stageAttachments/removeAttachment/validateAttachments` |
| Markdown | Headings, lists, quotes, emphasis, safe links | PASS | `MarkdownView` blocks + `AttributedString` + safe-link filtering |
| Markdown | Inline/fenced code with language label; long code scrolls; Copy Code | PASS | `MarkdownView.codeBlock` |
| Markdown | Long streaming Markdown stays stable | PASS (code) | Deterministic segmentation + scroll anchoring; device test |
| Errors | Offline/unauthorized/model/timeout/rate-limit/server errors recover safely; no duplicate messages | PASS (code) | Error translation + retry/resume paths; device test |
| Settings/UI | Clear Data confirmation states exact scope and removes that scope | PASS | `RootView.clearData` + `discardAll` + Composition Root credential purge; confirmation dialog |
| Settings/UI | Small/large iPhone + iPad keep primary actions visible | UNVERIFIED | Device test (adaptive layout + safe-area composer + `safeAreaInset`) |
| Settings/UI | Light/Dark readable | PASS (code) | Full light/dark token system + toggle |
| Settings/UI | Keyboard dismiss; unsent draft survives navigation/relaunch | PASS (code) | Draft persistence; device test |
| Settings/UI | Dynamic Type (incl. accessibility sizes) does not clip primary controls | UNVERIFIED | Device test; `MessageBubbleWidthPolicy` caps width, wraps long content |
| Settings/UI | VoiceOver order/labels/hints/traits/announcements cover primary flow | PASS (code) | Labels/actions + streaming announcements (A4); full flow audit is device test |
| Settings/UI | Rotation/safe areas | UNVERIFIED | Device test |
| Settings/UI | No overflow or literal localization keys | PASS | Localized (95 keys) |
| Privacy | Diagnostics/logs reveal no credential/message/file content | PASS | `Sensitive` redaction + `AttachmentImportCandidate` redaction |

---

## 11. Gap register and resolution plan

| ID | Gap | Layer | Severity | Resolution |
| --- | --- | --- | --- | --- |
| G-01 | `SendMessageRequest` selection vocabulary drift: spec text (DES-011 §3.1, DES-012 §3.3) declares `userSelection/workspacePreference/capabilityPreference` (ProviderIdentity-based); code ships `modelSelection: ProviderModelSelection` (provider+model). Semantics are preserved and improved (per-conversation provider/model, UX audit V2), but the frozen contract text no longer matches. | Application / Presentation | High (contract) | Revise DES-011 §3.1 and DES-012 provider-selection intent to the `modelSelection` vocabulary as an additive revision (Announce → Migrate → Remove), or restore the spec fields. The two docs must be updated together; verify no consumer constructs the old triple. |
| G-02 | Reduced motion not explicitly handled (`accessibilityReduceMotion`); custom spring animations may run with Reduce Motion enabled. | Presentation | Low | Honor `@Environment(\.accessibilityReduceMotion)` for the drawer/reveal/swipe animations (`OmniaTheme.Motion`), and add a checklist item. |
| G-03 | Foundation error-abort contract: DES-001 may require an error-abort contract; Foundation ships no error type (`CancelledOutcome` is not an `Error`). | Foundation | Low (pending DES-001 read) | Confirm the current DES-001 text; if it mandates an abort contract, add it to Foundation; otherwise close with a note. |
| G-04 | Background/foreground + lock during generation is not lifecycle-suspended; tasks continue off-screen by design. | App edge | Info | Confirm desired behavior against UX audit; add a lifecycle-suspension test or document as intended. |
| G-05 | High contrast and Dynamic-Type clipping at accessibility sizes are unverified on device. | Presentation | Info | Execute the `V1_DEVICE_TEST_CHECKLIST` device pass; triage P0/P1/P2 as documented. |
| G-06 | macOS keyboard navigation not evidenced (spec allows "where appropriate"). | Presentation | Info | Optionally add keyboard shortcuts for primary actions (new chat, send, menu) on macOS. |

Non-gaps confirmed as intended by the specs: language-aware syntax coloring (explicitly out of sprint), third-party packages (prohibited), multi-window/document lifecycle (out of scope), onboarding UI (out of scope), signing/notarization (out of v1.0.0 scope).

---

## 12. Build & test verification (Docker, Linux)

Executed 2026-08-16 with `swift:6.0` (already present locally), toolchain **Swift 6.0.3**, target **x86_64-unknown-linux-gnu** — matching the repo's CI target. Build path kept inside the container (`/tmp/omnia-build`); repo untouched.

| Target | Build | Tests executed | Failed |
| --- | --- | --- | --- |
| Root (`OmniaTests`, umbrella) | PASS | 1 | 0 |
| `OmniaFoundation` | PASS | 136 | 0 |
| `OmniaDomain` | PASS | 347 | 0 |
| `OmniaApplication` | PASS | 238 | 0 |
| `OmniaInfrastructure` | PASS | 293 | 0 |
| `OmniaPresentation` | PASS | 233 | 0 |
| `OmniaApp` | PASS | 55 | 0 |
| **Total** | **PASS** | **1303** | **0** |

Caveat: the root package declares a single umbrella test; the real coverage lives in the six package suites, all green.

---

## 13. Evidence index

- Specifications: `Documentation/Design/APPLICATION_API.md` (DES-011), `PRESENTATION_API.md` (DES-012), `APP_API.md` (DES-013), `INFRASTRUCTURE_API.md` (DES-010), `DOMAIN_API.md` (DES-009), `FOUNDATION_API.md`, `Design/API/*`, `Documentation/Architecture/01-09`.
- UI contract: `Documentation/UI/DESIGN_SYSTEM.md`, `COMPONENTS.md`, `README.md`, `SCREENS/CHAT.md`, `SCREENS/SETTINGS.md`.
- Acceptance criteria: `Documentation/Development/V1_DEVICE_TEST_CHECKLIST.md`.
- Code: the six packages under `Packages/` (sources + tests), `Package.swift`, `App/` (iOS/macOS shells).
