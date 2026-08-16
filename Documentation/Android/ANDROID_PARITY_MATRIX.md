# Android Parity Matrix — Android 1.0 vs. Actual iOS 1.0.0

| | |
| --- | --- |
| **Document** | ANDROID_PARITY_MATRIX |
| **Phase** | M0 — Contract Freeze |
| **Primary artifact** | Android-facing mapping of every iOS capability to an Android 1.0 parity requirement. |
| **Audit input** | `Documentation/Development/DESIGN_PARITY_MATRIX.md` (design→code audit) — used as evidence for the "iOS actual behavior" column; it is **not** a replacement for this matrix. |
| **Classes** | `REQUIRED` / `PLATFORM_SPECIFIC` / `DEFERRED` / `EXTENSION_POINT` — exactly one per row. |
| **Status** | `M0` — contract statement; updated to PASS/PARTIAL/GAP by the milestone that implements the row. |

## 1. How to read this matrix

The column **iOS actual behavior** records the **implemented runtime truth** (verified in Swift sources/tests). The **Documented intent / drift** column calls out where the design prose differs. Per the honesty rule, a row whose iOS behavior is device-dependent is marked **`[iOS unverified]`** and is never treated as proven by package tests; the Android requirement and its verification layer are set accordingly.

**Source-of-truth discrepancy G-01** applies to selection-related rows (P-01, P-06, P-08, GEN-19): the iOS **implementation** uses `SendMessageRequest(conversation:message:modelSelection:)` with a **`ProviderModelSelection` (provider + model)** pair persisted per conversation. The **stale spec text** (DES-011 §3.1, DES-012 §3.3) still names `userSelection: ProviderIdentity?` / `workspacePreference` / `capabilityPreference`. Android **records the implementation as the runtime truth** (`ProviderModelSelection`) and does not silently adopt either side; the mismatch is documented, not resolved by omission.

Verification-layer shorthand: **JVM** unit tests · **ViewModel** state tests · **Repo** repository/storage tests · **Network** provider/transport tests · **Compose** Compose UI tests · **Instr** instrumentation tests · **Device** real-device smoke. Full definitions in `ANDROID_TEST_MATRIX.md`.

---

## 2. Providers & models

| ID | Capability | iOS 1.0.0 actual behavior (runtime truth) | Documented intent / drift | Android 1.0 parity requirement | Class | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P-01 | Provider CRUD (add/edit/remove/list) | `ProviderConnectionService` configure/update/remove/all. Credential stored **by reference only**; `remove(_:)` also removes the stored credential, model key, and API-kind key. | DES-011 §3.4/§3.9/§3.10/§3.11 match. | Same service contract: add, edit, remove, list; removal cleans credential reference + model + API-kind keys. | REQUIRED | JVM+Repo+Compose | M0 |
| P-02 | OpenAI-compatible API | `OpenAICompatibleProviderAdapter` over `ProviderTransport`; `ChatCompletion` request/response/chunk DTOs; non-streaming + streaming; error translation. | DES-010 §3.5/§3.6/§3.9 match. | Same adapter contract and DTO mapping (prompt→single user message, history→ordered messages, `stream:true`, chunk delta→contentDelta, end→completion). | REQUIRED | Network | M0 |
| P-03 | Gemini API | `GeminiClient` (generate content, `:streamGenerateContent?alt=sse`, models list), `GeminiProviderAdapter`, `GeminiMapping`; auth only via `x-goog-api-key` from stored credential by reference. | DES-010 §3.10 match. | Same client/adapter/mapping; header-only auth; secret never in URL/logs/metadata. | REQUIRED | Network | M0 |
| P-04 | Provider API kind | `ProviderAPIKind` (`openAICompatible` default / `gemini`), Codable-persisted; apiKind surface idempotent; unrecorded resolves to default; family-routed binding (`ProviderAdapterBinding`). | DES-011 §3.11, DES-013 §3.3 match. | Same persisted value type + family-routed adapter factory; unrecorded kind → OpenAI-compatible default. | REQUIRED | JVM+Repo+Network | M0 |
| P-05 | Secure credential storage | Keychain on Apple; in-memory on Linux/tests; `CredentialStorageProtocol`; `credentialNotFound`/`storageUnavailable`; secrets never in files/logs. | DES-010 §3.4, ARC-005 match. | Android Keystore-backed store; in-memory store in JVM tests; same errors and isolation. Apple-specific mechanism → Android equivalent. | PLATFORM_SPECIFIC | JVM+Repo+Instr | M0 |
| P-06 | Test Connection | Real endpoint/credential validation without logging secrets; typed failures (invalid credential/unauthorized, unreachable, invalid endpoint, model unavailable, rate limit, timeout, server); failed test preserves form data. | M1 scope; DES-010 §3.10 inspector precedent. | Same typed validation with safe error copy; form state retained on failure. | REQUIRED | Network+Compose | M0 |
| P-07 | Model discovery | `GeminiProviderInspector.discoverModels()` from the provider's **real** catalog; never fabricated. | DES-010 §3.10 match. | Discovery from real catalog via the selected API family; configured/manual fallback when unsupported (G-07: never fabricate). | REQUIRED | Network+JVM | M0 |
| P-08 | Cached catalogs | Discovery → cache → manual entry; loading/loaded/empty/unavailable/stale/failed states; refresh never silently destroys a valid saved selection. | `AppEdgeConstants.defaultModelName` is legacy; production catalogs not inferred (G-07). | Same states and refresh rule; cached catalog keyed by provider + API kind. | REQUIRED | JVM+Repo | M0 |
| P-09 | Active/default provider and model | Default model selection constrained to its provider; deterministic migration order (valid default → legacy provider → first ready provider's first offered model); unavailable default identified, requires correction. | DES-011 §3.10, UX audit V2. | Same default coherence + correction-only behavior; no silent redirect. | REQUIRED | JVM+ViewModel | M0 |
| P-10 | Per-conversation provider/model selection | Persisted on the conversation aggregate; inherited by new conversations; retained across navigation/relaunch; selection vocabulary is **`ProviderModelSelection`** (runtime truth, G-01). | Docs stale: `userSelection/workspacePreference/capabilityPreference` (G-01). | Same value type + persistence + inheritance + retention; **modelSelection vocabulary**. | REQUIRED | JVM+Repo+ViewModel | M0 |
| P-11 | Capability gating | Generic gate over effective capabilities; `CapabilityError.providerUnavailable`/`modelUnavailable`; unknown metadata conservative; no provider-name switch forest. | M1 scope; DES-009 §3.5. | Same generic gate; transport support and model input support both respected. | REQUIRED | JVM+Network | M0 |

---

## 3. Generation

| ID | Capability | iOS 1.0.0 actual behavior (runtime truth) | Documented intent / drift | Android 1.0 parity requirement | Class | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GEN-01 | Text generation | `TextGenerationContract`/`ConversationContract`; non-streaming prompt→response; adapter maps DTOs. | DES-009/010 match. | Same contracts and mapping. | REQUIRED | Network | M0 |
| GEN-02 | Streaming | `StreamingContract.stream` → `AsyncThrowingStream<StreamingUpdate>`; deltas incremental with request identity; completion carries assembled assistant `Message`. | DES-009 §3.5, DES-010 §3.9.4 match. | Same `StreamingUpdate` model surfaced as `Flow<StreamingUpdate>`. | REQUIRED | Network+ViewModel | M0 |
| GEN-03 | Reasoning metadata | Not in the v1 capability set; `StreamingUpdate` has no reasoning channel. | DES-010 extension points. | **Not implemented in 1.0.** Parse-and-ignore unknown provider fields defensively; no reasoning UI. | EXTENSION_POINT | Network | M0 |
| GEN-04 | Vision (image understanding) | Image **attachments** exist; vision **understanding** is an extension point. | DES-010 extension points. | Send attachments only; never promise the model understands them. | EXTENSION_POINT | — | M0 |
| GEN-05 | Document input | Files importer (PDF, text, images) staged into app-owned storage; never retain external URL as sole durable reference. | M2 scope. | SAF-based input copied into app-owned storage; same rule. | REQUIRED | Instr+Device | M0 |
| GEN-06 | Image attachments | Photos picker → copy → preview chips → send with metadata; safe filename/type/size shown, never full paths. | M2 scope. | Photo Picker equivalent; same staging/preview/redaction. | REQUIRED | Instr+Compose+Device | M0 |
| GEN-07 | Multiple images | Multiple attachments up to explicit limits; duplicates from repeated selection prevented. | M2 scope. | Same multi-image staging and dedupe. | REQUIRED | Instr+Compose | M0 |
| GEN-08 | PDF | PDF attachment with bounded strategy (metadata + extraction limits); generic models response never proves native file input. | M2 scope. | Same bounded PDF handling; honest capability surface. | REQUIRED | JVM+Network | M0 |
| GEN-09 | Text files | Safe plain-text formats with bounded extraction; failures surfaced. | M2 scope. | Same whitelisted formats + extraction limits. | REQUIRED | JVM | M0 |
| GEN-10 | Attachment limits | 8 files / 10 MB per file / 25 MB aggregate / 200 000 extracted chars (`AttachmentLimits`). | DES-011-adjacent; M2. | Same explicit limits surfaced to the UI. | REQUIRED | JVM+Compose | M0 |
| GEN-11 | Attachment revalidation | Revalidate every staged item when provider/model changes; disable/explain unsupported; never silently drop. | M2 scope. | Same revalidation contract. | REQUIRED | ViewModel+JVM | M0 |
| GEN-12 | Streaming presentation states | Thinking / Streaming / completed / interrupted / error; distinct cards; VoiceOver announcements started/completed/interrupted. | DES-012 §3.2. | Same state model; TalkBack announcements (PLATFORM_SPECIFIC mechanism, REQUIRED behavior). | REQUIRED | ViewModel+Compose | M0 |
| GEN-13 | Auto-scroll | `ScrollViewReader` + anchor; jump-to-latest; user-scroll behavior preserved. | DES-012; UX. | Same auto-scroll + jump-to-latest. | REQUIRED | Compose | M0 |
| GEN-14 | Stop | Cancel is cooperative and awaited; interrupted partial preserved; slot released after terminal save. | DES-008; ARC-001. | Same cooperative cancel contract. | REQUIRED | ViewModel | M0 |
| GEN-15 | Retry | Interrupted stream resumes preserved partial; no user message appended. | M3 scope; UX audit U7. | Same resume semantics. | REQUIRED | ViewModel+JVM | M0 |
| GEN-16 | Continue/Resume | Resume carries partial content forward; rejects non-interrupted/non-stored conversations. | DES-011 §3.3. | Same resume contract. | REQUIRED | JVM+ViewModel | M0 |
| GEN-17 | Regenerate | Re-issues from last user prompt at/before index; stale reply truncated; no duplicate user message. | M3 scope (UI_REDESIGN). | Same in-place regenerate. | REQUIRED | ViewModel | M0 |
| GEN-18 | Interrupted generation persistence | Use case persists partial + marks conversation interrupted on interruption; restored after relaunch. | DES-011 §3.3. | Same persistence of interrupted state. | REQUIRED | JVM+Repo | M0 |
| GEN-19 | Generation ownership/isolation | Conversation-keyed coordinator; monotonic operation identity; updates accepted only for the current operation. | ARC-007; DES-012. | Same keyed coordinator + identity guard. Selection carried as `modelSelection` (G-01). | REQUIRED | ViewModel | M0 |
| GEN-20 | Navigation during generation | A→B→A, Providers/Settings/About during streaming never cancel or cross-contaminate; off-screen updates retained. | Protected baseline. | Same contract on Android navigation. | REQUIRED | Instr | M0 |
| GEN-21 | Background/foreground | Tasks continue while view unobserved; no voluntary cancellation on backgrounding; **device lock/background unverified `[iOS unverified]`** (G-04). | Protected baseline. | Same non-cancellation contract in foreground; no foreground service in v1; explicit Android contract for background (no cancel). | REQUIRED | Instr+Device | M0 |
| GEN-22 | Process/lifecycle recovery | Interrupted/completed state persisted and restored after relaunch; no duplicate records. | M4 scope. | Recovery from persisted records via ViewModel/SavedStateHandle; no duplicates. | REQUIRED | JVM+Instr+Device | M0 |
| GEN-23 | Late-chunk rejection | Stale operation terminal callbacks cannot mutate a replacement operation. | Coordinator contract. | Same guard. | REQUIRED | ViewModel | M0 |
| GEN-24 | Duplicate protection | Send/retry/resume/migration/crash produce no duplicate user or assistant messages. | M3/M4. | Same invariant, tested at JVM + instrumented layers. | REQUIRED | JVM+Instr | M0 |

---

## 4. Conversation management

| ID | Capability | iOS 1.0.0 actual behavior (runtime truth) | Documented intent / drift | Android 1.0 parity requirement | Class | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C-01 | Conversation lifecycle | create, create-in-workspace (atomic: missing workspace fails before create), open/switch, list-in-workspace, delete. | DES-011 §3.2/§3.8 match. | Same service contract. | REQUIRED | JVM+Repo | M0 |
| C-02 | Persistent history | Aggregate-owned history with roles, timestamps, attachments, model selection; round-trips exactly; restored after relaunch. | DES-009 §3.2 match. | Same aggregate + stable Android serialized form. | REQUIRED | JVM+Repo | M0 |
| C-03 | Rename | `rename(to:)` persists user title; empty/whitespace rejected; history unchanged. | DES-011 §3.2; Conversation.swift:118. | Same rename contract. | REQUIRED | JVM+Compose | M0 |
| C-04 | Auto-title precedence | Auto-title from first user message (80 chars); **user title (`titleOrigin = .user`) never overwritten**. | Conversation.swift:26-153. | Same `titleOrigin` precedence. | REQUIRED | JVM | M0 |
| C-05 | Search | Filter by title/preview, case-insensitive; search keeps activity groups; no-results state. | new_design.md §6. | Same filter behavior. | REQUIRED | Compose+JVM | M0 |
| C-06 | Date grouping | Today / Yesterday / Previous 7 Days / Older / Future; local calendar; correct at boundaries. | new_design.md §6. | Same groups with Android `java.time`/`kotlinx-datetime` local calendar. | REQUIRED | JVM+Compose | M0 |
| C-07 | Deletion | Full swipe never deletes; explicit confirmation dialog (a11y path); delete removes attachments, drafts, persisted state; active-conversation delete is safe. | UX audit U5; RootView.deleteConversation. | Same explicit-confirm delete. | REQUIRED | Compose+Instr | M0 |
| C-08 | Drafts | Per-conversation, debounced, persisted, restored on reopen, cleared on send, awaited before destructive boundaries. | UX audit U4; RootView. | Same draft store contract. | REQUIRED | JVM+Instr | M0 |
| C-09 | New conversation idempotence | Guarded create; no duplicates/orphans from repeated intent. | Protected baseline. | Same idempotence. | REQUIRED | ViewModel | M0 |

---

## 5. Markdown

| ID | Capability | iOS 1.0.0 actual behavior (runtime truth) | Documented intent / drift | Android 1.0 parity requirement | Class | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M-01 | Markdown blocks | Paragraphs, headings, ordered/unordered lists, block quotes, emphasis, horizontal rule via `MarkdownContent` blocks + `AttributedString`. | DES-012 §3.3.1. | Custom Compose renderer over the same block segmentation (see Architecture §4). | REQUIRED | JVM+Compose | M0 |
| M-02 | Inline code | Rendered via native markdown parsing. | DES-012 §3.3.1. | Same inline-code treatment. | REQUIRED | Compose | M0 |
| M-03 | Fenced code + language label | `codeBlock(content:language:)`; language label (or "Code"); monospaced; distinct background; preserved whitespace/wrapping; **no** syntax coloring. | DES-012 §3.3.1. | Same block, label, and monospace presentation. | REQUIRED | JVM+Compose | M0 |
| M-04 | Copy (whole message) | `UIPasteboard`/`NSPasteboard` copy of plain text. | M3 scope. | `ClipboardManager` equivalent. | REQUIRED | Compose | M0 |
| M-05 | Copy Code | Per-code-block Copy button with "Copied" feedback. | M3 scope. | Same affordance. | REQUIRED | Compose | M0 |
| M-06 | Long code horizontal scroll | Horizontal `ScrollView` for long fenced code. | M3 scope. | Same horizontal scroll. | REQUIRED | Compose | M0 |
| M-07 | Safe links | Only http/https/mailto render as links; arbitrary HTML/scripts never execute. | MarkdownView.attributed. | Same scheme allow-list; no HTML execution. | REQUIRED | Compose+JVM | M0 |
| M-08 | Language-aware syntax highlighting | Explicitly not in sprint. | DES-012 §3.3.1. | **Deferred** beyond Android 1.0. | DEFERRED | — | M0 |

---

## 6. Errors & resilience

| ID | Capability | iOS 1.0.0 actual behavior (runtime truth) | Documented intent / drift | Android 1.0 parity requirement | Class | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| E-01 | Offline / network errors | Transport failures → `CapabilityError.providerUnavailable`; localized copy + retry. | DES-010 §3.9.3. | Same taxonomy + safe copy. | REQUIRED | Network+Compose | M0 |
| E-02 | Unauthorized / invalid key | Distinguishable typed failure; no secret in error. | M1/M3. | Same distinction. | REQUIRED | Network | M0 |
| E-03 | Invalid endpoint | Boundary validation: non-empty absolute http(s) URL; malformed rejected before storage. | DES-011 §3.9. | Same validation. | REQUIRED | JVM | M0 |
| E-04 | Invalid/unavailable model | `CapabilityError.modelUnavailable`; requires explicit replacement; no silent redirect. | DES-011 §3.10. | Same. | REQUIRED | JVM+Network | M0 |
| E-05 | Unsupported capability/attachment | Rejected with clear validation; never sent to a model known not to accept it. | M2 scope. | Same. | REQUIRED | JVM+ViewModel | M0 |
| E-06 | Timeout | Typed; retry safe. | M1/M3. | Same. | REQUIRED | Network | M0 |
| E-07 | Rate limit | Typed; retry safe; no duplicate request. | M1/M3. | Same. | REQUIRED | Network | M0 |
| E-08 | Server errors | Typed; localized; recovery without duplicates. | M3. | Same. | REQUIRED | Network+Compose | M0 |
| E-09 | Malformed responses | `invalidResponse`; partial content preserved where applicable. | DES-010 §3.9.3. | Same. | REQUIRED | Network | M0 |
| E-10 | Interrupted stream | `streamingInterrupted(partialContent:)`; partial never silently discarded. | DES-010 §3.9.4. | Same. | REQUIRED | Network+ViewModel | M0 |
| E-11 | Local persistence/file errors | `RepositoryError.storageUnavailable`; storage never owns business logic. | DES-010 §3.1. | Same. | REQUIRED | Repo | M0 |
| E-12 | Malformed persisted records | Strict identity restoration; stable round-trip; decode failures recoverable. | M4 scope. | Same strictness; malformed single record must not wipe everything. | REQUIRED | Repo | M0 |
| E-13 | Corrupted-record isolation | One malformed draft never makes its conversation unreachable (`restoreDraft` catch). | M4 scope. | Same isolation for drafts and all per-record corruption. | REQUIRED | Repo | M0 |

---

## 7. App, settings, UI, platform

| ID | Capability | iOS 1.0.0 actual behavior (runtime truth) | Documented intent / drift | Android 1.0 parity requirement | Class | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S-01 | First-launch Add Provider guidance | No-provider empty state exposes Add Provider CTA; no dead-end send; cancel/back recoverable. | SCREENS/CHAT.md; UX. | Same first-run guidance. | REQUIRED | Compose+Instr | M0 |
| S-02 | Appearance | Dark first-launch default + light option; toggle in drawer + Settings; persisted at workspace level; restored at launch. | new_design.md §13; RootView. | Same toggle + persistence; dark default. | REQUIRED | Compose+Instr | M0 |
| S-03 | Settings sections | Configuration (typed values), Appearance (Dark Mode row), About. | SCREENS/SETTINGS.md. | Same sections. | REQUIRED | Compose | M0 |
| S-04 | About | Version/build, branding, workspace context. | M5 scope. | Same content from Android `BuildConfig`. | REQUIRED | Compose | M0 |
| S-05 | Clear Data | Explicit destructive confirmation with exact scope; deletes chats/attachments/drafts/providers/config; purges credential namespace; generation awaited first. | M4 scope; RootView. | Same scope + confirmation + purge. | REQUIRED | Instr+Device | M0 |
| S-06 | Credential namespace cleanup | Provider removal and Clear Data clean the app credential namespace. | ARC-005; CompositionRoot. | Same cleanup contract. | REQUIRED | Repo+Instr | M0 |
| S-07 | Accessibility (TalkBack) | Labels, hints, combined rows, custom actions (rename/delete), streaming announcements. | UX audit A4; ConversationListView. | TalkBack content descriptions + live-region announcements; same coverage. Apple-specific mechanism → Android equivalent. | PLATFORM_SPECIFIC | Compose+Device | M0 |
| S-08 | Reduce motion | **Not handled in iOS `[iOS gap G-02]`.** | G-02. | **Required on Android**: respect animator duration scale / reduced-motion for drawer, swipe, message animations. | PLATFORM_SPECIFIC | Instr | M0 |
| S-09 | Font scaling | iOS Dynamic Type scaling; clipping at accessibility sizes `[iOS unverified]` (G-05). | G-05. | `sp` typography + `fontScale`; primary controls never clipped; device-verified. | PLATFORM_SPECIFIC | Instr+Device | M0 |
| S-10 | High contrast | iOS unverified (G-05). | G-05. | Respect system high-contrast; verify at instrumented/device layers. | PLATFORM_SPECIFIC | Instr+Device | M0 |
| S-11 | Picker mechanics | PhotosUI `PHPicker` + file importer (UTType). | M2 scope. | Android Photo Picker + Storage Access Framework; same staging semantics. Apple-specific mechanism → Android equivalent. | PLATFORM_SPECIFIC | Instr+Device | M0 |
| S-12 | System navigation (Back) | iOS Back affordance / navigation stack. | DES-012 §3.5. | System Back + predictive back; same route model (`NavigationState`). Apple-specific mechanism → Android equivalent. | PLATFORM_SPECIFIC | Instr | M0 |
| S-13 | Rotation | State survives via SwiftUI. | — | Compose/ViewModel state survives configuration changes; streaming continues. Apple-specific mechanism → Android equivalent. | PLATFORM_SPECIFIC | Instr | M0 |
| S-14 | Process death / Activity recreation | iOS: persistence-based recovery (G-04 contract). | M4. | ViewModel + SavedStateHandle + persisted records; recovery contract of GEN-22. Apple-specific mechanism → Android equivalent. | PLATFORM_SPECIFIC | Instr+Device | M0 |
| S-15 | Keyboard / IME | `safeAreaInset` composer; keyboard dismissal preserves draft. | UX. | `imePadding`/`WindowInsets`; same draft preservation. Apple-specific mechanism → Android equivalent. | PLATFORM_SPECIFIC | Instr+Device | M0 |

---

## 8. Cross-cutting

| ID | Capability | iOS 1.0.0 actual behavior (runtime truth) | Documented intent / drift | Android 1.0 parity requirement | Class | Verification | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| X-01 | Privacy / logging constraints | `Sensitive` redaction; no credentials, messages, file bytes, or full paths in logs/diagnostics; import candidates metadata-only. | ARC-005; M4. | Same redaction contract in `:core` logging and `:app` import candidates; verified by tests that assert redaction. | REQUIRED | JVM | M0 |
| X-02 | Localization | All user-visible strings localized (Localized catalog, 95 keys); no literal keys in v1 flows. | DES-012. | Same: Android resource-based localization, English complete; no literal keys. | REQUIRED | Compose+JVM | M0 |
| X-03 | Workspaces UI | Single implicit default workspace; no management UI. | DES-013 §3.4. | **Deferred** — same implicit workspace only. | DEFERRED | — | M0 |
| X-04 | Accounts / cloud sync | Out of v1 scope. | OMNIA scope §6. | **Deferred.** | DEFERRED | — | M0 |
| X-05 | Analytics / telemetry | None. | OMNIA scope §6. | **Deferred** (none added). | DEFERRED | — | M0 |

---

## 9. Additional capability families (extension points)

| ID | Capability | iOS 1.0.0 actual behavior | Android 1.0 parity | Class | Status |
| --- | --- | --- | --- | --- | --- |
| GEN-EX-01 | Image generation, embeddings, tool calling, structured output, audio | iOS extension points (not in v1 capability set). | Not implemented; contracts left open. | EXTENSION_POINT | M0 |

---

## 10. Summary counts

| Class | Rows |
| --- | --- |
| REQUIRED | 69 |
| PLATFORM_SPECIFIC | 10 |
| DEFERRED | 4 |
| EXTENSION_POINT | 3 |
| **Total** | **86** |

*Counts verified by enumerating every parity row in §2–§9 at contract freeze (REQUIRED 69, PLATFORM_SPECIFIC 10, DEFERRED 4, EXTENSION_POINT 3, total 86). Recompute when rows change; the table never diverges silently from the rows above it.*

## 11. Five-category classification recap

| Category | Where it lives |
| --- | --- |
| 1. Actual implemented iOS behavior | The "iOS actual behavior" column throughout (runtime truth). |
| 2. Documented intended behavior | The "Documented intent / drift" column where it agrees with behavior. |
| 3. Stale / spec-drift behavior | G-01 rows (P-01, P-06, P-08, GEN-19) — recorded, not adopted. |
| 4. Apple-specific requiring Android equivalent | `PLATFORM_SPECIFIC` rows (P-05, S-07..S-15) with mechanism mapping in `ANDROID_MIGRATION_MAP.md`. |
| 5. Deferred beyond Android 1.0 | `DEFERRED` rows (M-08, X-03, X-04, X-05). |
