# Android 1.0 Scope — REQUIRED / PLATFORM_SPECIFIC / DEFERRED / EXTENSION_POINT

| | |
| --- | --- |
| **Document** | ANDROID_V1_SCOPE |
| **Phase** | M0 — Contract Freeze |
| **Parity target** | Actual Omnia iOS 1.0.0 implementation (runtime truth), not stale spec prose. |
| **Discrepancy note** | The `SendMessageRequest` selection vocabulary (G-01) is recorded as **`ProviderModelSelection` (provider + model) — the runtime truth**; the stale `userSelection/workspacePreference/capabilityPreference` terminology is not copied. See `ANDROID_README.md` §4 and `ANDROID_PARITY_MATRIX.md` P-01/P-06/P-08. |

Every parity entry in `ANDROID_PARITY_MATRIX.md` is classified into exactly one of the four buckets below. This file defines the buckets and enumerates the contract-level scope; the matrix is authoritative for individual rows.

## 1. REQUIRED — must ship in Android 1.0

Behavioral parity to the iOS implementation, verified per `ANDROID_TEST_MATRIX.md`.

**Providers & models**
- Provider CRUD: add, edit, remove, list (configure/update/remove/all), with credential stored **by reference only**; `remove` also removes the stored credential reference, the recorded model key, and the recorded API-kind key.
- OpenAI-compatible API path (text generation, conversation, streaming).
- Gemini API path (generate content, `:streamGenerateContent?alt=sse`, models list).
- Provider API kind: persisted per connection (`openAICompatible` default / `gemini`), family-routed adapter binding, unrecorded kind resolves to default.
- Test Connection: validates the real endpoint/credential path without logging secrets; typed failures (invalid credential/unauthorized, unreachable/no network, invalid endpoint, model unavailable, rate limit, timeout, server failure); failed test preserves form data.
- Model discovery from the provider's real catalog; configured/manual fallback when discovery is unsupported; **never a fabricated catalog** (G-07).
- Cached catalogs: discovery → cache → manual; loading/loaded/empty/unavailable/stale/failed states; refresh never silently destroys a valid saved selection.
- Active/default provider and model; default model constrained to its provider.
- Per-conversation provider/model selection, persisted, inherited by new conversations, retained across navigation/relaunch; unavailable saved selection requires explicit replacement (never silent redirect).
- Generic capability gating (no provider-name switch forest).

**Generation**
- Text generation, conversation send, and streaming with incremental content deltas.
- Thinking / streaming / completed / interrupted / error presentation states mirroring iOS.
- Auto-scroll during streaming; jump-to-latest.
- Stop (cancel) preserves the interrupted partial content.
- Retry (resume preserved partial) and Continue/Regenerate without duplicating user or assistant messages.
- Interrupted generation persisted as incomplete and restored after relaunch.
- Generation ownership/isolation keyed by conversation and request identity; late chunks from a stale operation never mutate a replacement operation.
- Navigation during generation (conversation A→B→A, Providers, Settings, About) never cancels or cross-contaminates.
- Background/foreground: generation continues in foreground across navigation; after process death the persisted record defines recovery (no foreground Service).
- Duplicate protection (send, retry, resume, migration, crash recovery).

**Conversation management**
- Conversation lifecycle: create, create-in-workspace, open/switch, list-in-workspace, delete.
- Persistent history with message roles, timestamps, attachments, and per-conversation provider/model.
- Rename persists; **auto-title never overwrites a user title** (title origin precedence).
- Search by title/preview; date grouping (Today / Yesterday / Previous 7 Days / Older / Future); stable sort and selection.
- Deletion with explicit destructive confirmation (full swipe never deletes) and safe active-conversation deletion.
- Per-conversation drafts: persisted, survive navigation and relaunch, cleared on send, never lost on picker error/cancel.

**Markdown**
- Paragraphs, headings, lists, block quotes, emphasis; inline code; fenced code with language label; horizontal scroll for long code; Copy (whole message) and Copy Code; safe links (http/https/mailto only); safe incremental streaming rendering; arbitrary HTML/scripts never execute.

**Errors & resilience**
- Typed error taxonomy with localized copy and contextual actions: offline/unreachable, unauthorized/invalid key, invalid endpoint, invalid/unavailable model, unsupported capability/attachment, timeout, rate limit, server error, malformed response, interrupted stream, local persistence/file error.
- No retry that duplicates a completed request; partial content and interruption semantics preserved.
- Malformed persisted records do not make the app or a conversation unreachable (corrupted-record isolation).

**App / settings**
- First-launch "Add Provider" guidance with a clear CTA; no dead-end send without a ready provider/model; cancel/back leaves recoverable state.
- Appearance: dark first-launch default + light option; toggle in the navigation drawer and Settings; persisted at the user-owned workspace level and restored on launch.
- Settings: Configuration (typed values), Appearance (Dark Mode row), About.
- About: version/build, branding.
- Clear Data with explicit destructive confirmation stating exact scope; removes conversations, attachments, drafts, providers, configuration; purges the app credential namespace.
- Localization: all user-visible strings localized, no literal keys in v1 flows (English complete).
- Privacy/logging: no credentials, tokens, message content, file content, or full private paths in logs/diagnostics/UI; error copy uses only safe metadata.

## 2. PLATFORM_SPECIFIC — required, realized with native Android equivalents

Behavior required for parity whose implementation mechanism is Android-native. Each maps to an Apple mechanism in `ANDROID_MIGRATION_MAP.md`.

- **Secure credential storage**: Android Keystore-backed credential storage (Keystore secret or `EncryptedSharedPreferences` for the reference namespace), mirroring iOS Keychain (in-memory backend on Linux/tests → in-memory `CredentialStore` in JVM tests). Contract errors `credentialNotFound` / `storageUnavailable` preserved.
- **Photo Picker**: Android Photo Picker (photo picker API, no storage permission) replacing PhotosUI `PHPicker`; same staging semantics (copy to app-owned storage, dedupe, remove-before-send, metadata-only display).
- **Storage Access Framework**: SAF (`ACTION_OPEN_DOCUMENT`, persisted URIs only for user-picked documents, content copied into app-owned storage) replacing the iOS file importer; never retain a temporary external URI as the sole durable reference.
- **System navigation**: system Back and predictive back handling mirroring iOS navigation; Back pops the navigation stack like the iOS Back affordance.
- **Rotation / configuration changes**: state survives via ViewModel + Compose state (iOS `@State`/navigation analog); streaming continues.
- **Process death / Activity recreation**: `ViewModel` + `SavedStateHandle` + persisted records define recovery; parity with iOS persistence-on-interruption.
- **Keyboard / IME**: `imePadding` / `WindowInsets` handling so the composer stays usable with the keyboard; keyboard dismissal preserves the draft (iOS keyboard/safe-area analog).
- **TalkBack**: content descriptions, labels, hints, custom actions (rename/delete), and streaming-lifecycle announcements (started/completed/interrupted), mirroring iOS VoiceOver + `UIAccessibility` announcements.
- **Font scaling**: `sp` typography and `fontScale` handling so primary controls are never clipped at accessibility sizes (iOS Dynamic Type analog). Device-verified, not claimed from unit tests (G-05).
- **High contrast**: respect system high-contrast / display settings for the token surface (iOS unverified; Android verified at instrumentation + device layers).
- **Reduce motion**: respect `ANIMATOR_DURATION_SCALE`/reduced-motion settings for drawer, swipe-reveal, and message animations (iOS gap G-02; required on Android).
- **Clipboard**: `ClipboardManager` for Copy / Copy Code (iOS `UIPasteboard` analog).
- **Light/dark**: in-app toggle remains the source of truth (dark default); Android may additionally follow the system only where it does not change the user-visible toggle contract.

## 3. DEFERRED — beyond Android 1.0

Functionality the iOS product explicitly defers, or that is out of v1 scope. Android does not build these in 1.0.

- **Language-aware syntax highlighting** in code blocks (iOS: explicitly not in sprint; fenced-code language labels are REQUIRED, coloring is DEFERRED).
- **Workspace management UI** (iOS: workspace is a single implicit default; no management UI).
- **Onboarding beyond the Add Provider CTA** (iOS: no onboarding flow; first-provider guidance only).
- **Accounts / cloud sync / collaborative chats** (iOS out of scope).
- **Voice / push notifications** (iOS out of scope).
- **Plugin / tool / MCP ecosystem** (iOS out of scope).
- **Built-in web search** (iOS out of scope).
- **Image-generation UI** (iOS out of scope).
- **Analytics / telemetry** (iOS out of scope; Android adds none).
- **Provider-specific branded UI** (iOS: generic presentation only).
- **Arbitrary background execution modes / foreground services for generation** (iOS: no invented background modes; Android follows).
- **macOS keyboard shortcuts** (G-06: iOS-only, not applicable on Android).

## 4. EXTENSION_POINT — capability families the v1 contract does not realize

Mirrors the iOS extension-point set. Android 1.0 keeps the contracts open without implementing them.

- **Reasoning metadata** (iOS: not in the v1 capability set; `StreamingUpdate` has no reasoning channel). Android must parse and ignore unknown provider reasoning fields defensively, and must not expose a UI for them in 1.0.
- **Vision / image understanding** (iOS: image **attachments** are REQUIRED; vision **understanding** is an extension point). Android sends attachments; it does not promise the model understands them.
- **Image generation, embeddings, tool calling, structured output, audio** (iOS extension points).

## 5. Acceptance rule

An Android 1.0 item is complete when its `ANDROID_PARITY_MATRIX.md` row's verification layer has been executed and passed, and no P0/P1 finding remains in the milestone audit. Device-only layers (instrumentation, real-device smoke) are not replaced by JVM unit results — the honesty rule of `ANDROID_README.md` §5 applies on Android exactly as on iOS.
