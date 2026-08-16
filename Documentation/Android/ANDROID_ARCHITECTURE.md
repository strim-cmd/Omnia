# Android Architecture — Dependency Graph, Preserved Semantics, and Not-Copied Mechanics

| | |
| --- | --- |
| **Document** | ANDROID_ARCHITECTURE |
| **Phase** | M0 — Contract Freeze |
| **Parity target** | Actual Omnia iOS 1.0.0 implementation (runtime truth). |
| **Related** | `ANDROID_V1_SCOPE.md`, `ANDROID_PARITY_MATRIX.md`, `ANDROID_MIGRATION_MAP.md` |

## 1. Modules and dependency graph

The Swift package set (`OmniaFoundation`, `OmniaDomain`, `OmniaApplication`, `OmniaInfrastructure`, `OmniaPresentation`, `OmniaApp`) maps to Gradle modules. **Names deliberately mirror the Swift layer names** so ownership rules and the migration map stay 1:1.

```text
            ┌───────────────┐
            │  :app-shell   │  Composition root, storage layout, adapter binding,
            │  (edge only)  │  first-run bootstrap, MainActivity, navigation host
            └──────┬────────┘
                   │ depends on :presentation, :app, :data, :domain, :core
   ┌───────────────┼─────────────────────┐
   │               ▼                     │
   │  ┌────────────────────┐             │
   │  │    :presentation   │  Compose UI, state models, generation
   │  │ (renders + intents)│  coordinator, Markdown renderer, a11y, theme
   │  └───────┬────────────┘             │
   │          │ depends on :app + :core  │  (NEVER :data, NEVER :domain directly)
   │          ▼                          │
   │  ┌────────────────────┐             │
   │  │        :app        │  Use cases: ConversationService, WorkspaceService,
   │  │ (orchestrates only)│  ProviderConnectionService, ConfigurationService,
   │  │                    │  SendMessageUseCase, AttachmentService, validation
   │  └───────┬────────────┘             │
   │          │ depends on :domain + :core
   │          ▼                          │
   │  ┌────────────────────┐             │
   │  │       :data        │  File store, serializers, Keystore credential storage,
   │  │  (implements only) │  OpenAI-compatible + Gemini clients/adapters/inspector,
   │  │                    │  transport seam, model catalog cache
   │  └───────┬────────────┘             │
   │          │ depends on :domain + :core
   │          ▼                          │
   │  ┌────────────────────┐             │
   │  │       :domain       │  Aggregates, value types, repository/capability/
   │  │  (owns invariants)  │  credential/config protocols, selection + lifecycle
   │  └───────┬────────────┘             │
   │          │ depends on :core         │
   │          ▼                          │
   │  ┌────────────────────┐             │
   │  │        :core       │  Identifier, Clock, Cancellation, Logger/Sensitive,
   │  └────────────────────┘  Environment, Lifecycle, SemanticVersion, errors
   └────────────────────────────────────┘
```

**Edge rules (identical to Swift):**

- `:presentation` and `:app` must **never** reference `:data`. Presentation renders state and translates intent; Application orchestrates use cases. This is the iOS rule "the Composition Root is the only place concrete Infrastructure implementations are referenced."
- `:app-shell` is the **only** module allowed to depend on every other module and the **only** place concrete `:data` implementations are wired.
- No module may depend on `:app-shell` (no upward edges).
- No mutable global singleton or second source of truth for any state (iOS rule).

## 2. The composition root

- **Hand-written, manual composition** in `:app-shell` — mirrors the Swift rule "no dependency-injection framework." Constructor-injected collaborators only.
- Ordering contract (mirrors DES-013 §3.1): storage root → repositories (one directory each) → credential storage → application services → runtime provider adapter binding → presentation surfaces → root composable (`RootApp` host).
- No business logic, networking, persistence, or credential operations in the composition code.

## 3. Semantics preserved on Android

These behavioral contracts are carried over verbatim from the iOS implementation:

| Semantics | iOS source | Android preservation |
| --- | --- | --- |
| Streaming event model | `StreamingUpdate` = `contentDelta(partialContent)` / `completion(message)` / `interruption(partialContent)` | Same sealed event model in `:domain`; `Flow<StreamingUpdate>` to the UI. Completion carries the assembled assistant message; interruption preserves partial content. |
| Selection priority | User explicit selection → workspace/capability preference → deterministic ready-provider order; failed selection → `CapabilityError.providerUnavailable` | Same policy in `:domain` `ProviderSelectionService`. |
| Selection vocabulary | **`ProviderModelSelection` (provider + model)** — runtime truth (G-01). Stale `userSelection/workspacePreference/capabilityPreference` is not copied. | Same value type; persisted per conversation; inherited by new conversations. |
| Capability gating | Generic, no provider-name switch forest; `CapabilityError.modelUnavailable` / `providerUnavailable` | Same generic gate over effective capabilities; unknown metadata stays conservative. |
| Attachment limits | 8 files / 10 MB per file / 25 MB aggregate / 200 000 extracted chars | Same `AttachmentLimits` defaults in `:app`. |
| Attachment revalidation | Revalidate staged attachments whenever provider/model changes | Same: revalidate in the coordinator on selection change; never silently drop or send unsupported items. |
| Auto-title precedence | User title (`titleOrigin = .user`) never overwritten by auto-title from first user message | Same `titleOrigin` logic in the `:domain` Conversation aggregate. |
| Configuration resolution | providerSettings → workspaceOverride → globalDefault → capabilityPreference; higher level wins; typed `ConfigurationKey<Value>` | Same typed keys + resolution order. |
| Configuration surfaces | Provider-settings keys for credential reference, endpoint, model, API kind; remove() also removes credential + model + API-kind keys | Same key ownership and cleanup contract. |
| Storage layout semantics | Application Support root + stable app-named dir; one directory per repository (Workspaces/, Conversations/, Providers/, Configuration/); lazy directory creation on first save; credentials never in the file layout | `context.filesDir`-rooted layout with the same per-aggregate namespaces, lazy creation, and credential exclusion. |
| Draft persistence | Per-conversation draft, debounced, cleared on send, restored on reopen, awaited before destructive boundaries | Same draft store contract. |
| Generation ownership/isolation | Conversation-keyed coordinator; monotonic operation identity; late updates from a stale operation rejected | Same keyed coordinator pattern with an operation identity guard. |
| Clear Data scope | Confirmation with exact scope; deletes chats/attachments/drafts/providers/configuration; purges the app credential namespace | Same scope and namespace purge. |
| Error translation | Transport/credential/capability failures surface as the exact typed errors, never wrapped | Same typed-error boundary in `:data`/`:app`. |
| Privacy | `Sensitive` redaction; no credentials/messages/file bytes in logs | Same redaction contract in `:core` logging + `:app` import candidates. |

## 4. Swift implementation details intentionally NOT copied

Parity is behavioral, not mechanical. The following are deliberately not reproduced:

| Swift detail | Android equivalent |
| --- | --- |
| `actor` structured concurrency | Kotlin coroutines + `StateFlow`/`Mutex`; the coordinator is a single-threaded scope, not an actor. |
| `@State` / `@MainActor` property wrappers | Compose state hoisting + `ViewModel` on the main dispatcher. |
| `AsyncThrowingStream<StreamingUpdate, Error>` | `Flow<StreamingUpdate>` (errors via typed sealed results at the boundary). |
| `throws` + Swift typed errors | Sealed result/typed exceptions at module boundaries; same error semantics. |
| Swift value semantics (`struct`, `Equatable`/`Sendable`) | Immutable Kotlin `data class`/value types; no shared mutable state. |
| `FileManager` JSON document store | `:data` file store over `filesDir` + a versioned JSON serializer. **File format is not byte-compatible with iOS and does not need to be** (separate apps, no data interchange). It must be stable across Android versions and round-trip exactly. |
| Keychain backend (Apple) / in-memory (Linux tests) | Android Keystore-backed store; in-memory store in JVM tests. Same `credentialNotFound`/`storageUnavailable` contract. |
| SwiftUI `NavigationStack` | Compose Navigation (or `NavHost`), one root with a drawer overlay. |
| PhotosUI `PHPicker` + file importer | Android Photo Picker + Storage Access Framework. |
| `AttributedString(markdown:)` native parsing | **Custom Compose Markdown renderer over the same block segmentation** (`paragraph/heading/list/quote/hr/codeBlock(content:language:)`). Rationale: preserves the iOS "no third-party renderer" principle and the exact block model; prose formatting uses `AnnotatedString` with the same safe-link filter (http/https/mailto only). |
| `UIPasteboard` | `ClipboardManager`. |
| `UIAccessibility.post(.announcement)` / VoiceOver | TalkBack announcements via `AccessibilityManager` / live regions. |
| `@State`-scoped session state | `ViewModel` + `SavedStateHandle`; process death recovers from persisted records. |
| SwiftPM manifests + Linux-testable composition root | Gradle modules; JVM unit tests run the platform-independent logic without an emulator. |
| `@available(iOS 16, macOS 13)` view isolation | `:presentation` Compose is JVM-compiled but UI-tested at the Compose/instrumentation layer. |

## 5. Concurrency and lifecycle contract

- **Navigation during generation**: the generation coordinator's operations and latest states are keyed by conversation identity; route changes alter only which state is rendered, never the lifetime or ownership of a request. Identical to the iOS coordinator.
- **Stop/Retry/Continue**: cancellation is cooperative and awaited before the operation slot is released, so a replacement request cannot be overwritten by a late cancellation save. Interrupted partial content is retained.
- **Background/foreground**: no voluntary cancellation on backgrounding. In foreground, generation continues; the app does **not** run a foreground service in v1 (iOS parity: no invented background modes). Android defines the explicit contract G-04: after process death, relaunch recovers from the persisted record.
- **Process death**: all state that must survive relaunch is persisted through the repositories/use cases (conversations, messages, interrupted partials, drafts, per-conversation selections, appearance, provider config) — same persistence boundary as iOS. View-layer-only state (scroll position, open menus, pending confirmation) is not required to survive process death.

## 6. Module owners (summary)

| Module | Responsibility | Owner role |
| --- | --- | --- |
| `:core` | Cross-cutting value types, logging, clock, cancellation | Platform-agnostic Kotlin |
| `:domain` | Aggregates, invariants, contracts | Domain |
| `:data` | Transport, persistence, credentials, catalog cache | Infrastructure |
| `:app` | Use cases, boundaries, validation | Application |
| `:presentation` | Compose UI, state, coordinator, a11y, theme | Presentation |
| `:app-shell` | Wiring, bootstrap, edge constants, host | App edge / composition |
