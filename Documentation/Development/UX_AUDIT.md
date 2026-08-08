---
title: UX Audit
document_id: UX-001
version: 0.9.0
status: Phase 1 Implemented; U5, U8, U4, A3, A4, U6, U7, V1 Implemented
created: 2026-08-07
project: Omnia
related_documents:
  - Documentation/Design/PRESENTATION_API.md
  - Documentation/Design/APP_API.md
  - .ai/standards/UI.md
  - Documentation/Product/PRODUCT_CHARTER.md
---

# UX Audit — Omnia (iOS + macOS)

## Purpose

Record the findings of the UX audit requested in issue #154: review the current iOS/macOS UI and the primary user flow end-to-end, verify each suspected finding against the actual implementation, and produce a prioritized list of findings and recommended next issues. Phase 1 of the prioritized implementation order is implemented, and the Phase 2 items U5 (confirmation for destructive actions), U8 (configure-form validation and keyboards), U4 (draft preservation), A3 (consistent bubble accessibility), A4 (streaming announcements and responding indicator), U6 (loading state distinct from empty state), and U7 (retry/continue for interrupted responses; provider endpoint edit), and V1 (semantic colors, contrast, Dynamic Type) are implemented (see [Implementation Status](#implementation-status)); no other implementation is performed by this audit.

## Scope

- The SwiftUI view layer: `RootView`, `ConversationListView`, `ConversationScreenView`, `MarkdownView`, `SettingsView`, `ProviderConnectionFormView` (`Packages/OmniaPresentation/Sources/OmniaPresentation/`).
- The application shells: `OmniaAppExecutable` (macOS) and `OmniaiOSApp` (iOS), and the platform-independent launch surface (`AppLaunch`, `FirstRunBootstrap`).
- The presentation state models (`ConversationListState`, `ConversationScreenState`, `SettingsState`, `NavigationState`) and the surfaces that produce them (`ConversationListSurface`, `ConversationScreenSurface`, `SettingsSurface`).
- The app targets' build settings relevant to UI (`App/Omnia.xcodeproj`).
- Evaluation criteria: `.ai/standards/UI.md`, the Apple Human Interface Guidelines, and the frozen contracts DES-012 / DES-013, with the architecture constraints ARC-001 (failures never silent), ARC-002, ARC-005, ARC-006, ARC-007, ARC-009, ADR-0001.

## Non-Goals

- No implementation, behavior change, API change, or specification revision.
- No design-system authoring.
- No platform-blocked physical launch verification (DES-013 §3.6, issue #124 AC5); findings are grounded in code review and build artifacts.

## Verification Method

Every suspected finding from issue #154 was checked against the current source at commit `develop`. The audit then searched the full view layer for additional issues. Findings below cite exact file and symbol; each states current behavior, why it is a UX problem, a recommended fix, and acceptance criteria.

## Findings

Severity: **P0** = blocks a core flow / data loss / security; **P1** = significant UX or accessibility defect in a primary flow; **P2** = quality, consistency, or secondary-flow defect; **P3** = polish.

### Accessibility

#### A1 — macOS removal intent is hidden behind iOS-only swipe actions (P1)

- **File/symbol:** `ConversationListView.swift:93-99` (`row.swipeActions`), `SettingsView.swift:116-122` (`connectionRow.swipeActions`).
- **Current behavior:** Delete (conversations) and Remove (provider connections) exist only as `.swipeActions(edge: .trailing, allowsFullSwipe: true)`. There is no `.contextMenu`, no toolbar button, and no in-row button anywhere in the app (`grep` confirms the only swipe actions are these two).
- **Why it is a UX problem:** On macOS, the swipe gesture is trackpad-dependent and offers no mouse or full-keyboard-access affordance. A mouse-only macOS user — the primary platform of the Beta v0.5 distribution — cannot remove a conversation or a provider connection, which are core destructive actions of the documented flow. Violates UI.md ("full keyboard access on macOS").
- **Recommended fix:** Add `.contextMenu` with Delete/Remove on both row types (and/or an explicit row accessory on macOS); keep `swipeActions` for iOS. Give the destructive action confirmation (see U5).
- **Acceptance criteria:**
  - On macOS, conversation and provider rows expose Delete/Remove via right-click context menu and full keyboard access.
  - On iOS, swipe removal still works.
  - Removing a provider never loses the Keychain credential without a confirming step.

#### A2 — Failure banners announce only "Error" and drop the failure detail (P1)

- **File/symbol:** `ConversationListView.swift:117-127`, `ConversationScreenView.swift:157-168`, `SettingsView.swift:160-170` (`failureBanner(_:)` in all three views).
- **Current behavior:** Each banner renders the fixed text "Something went wrong. Please try again." and applies `.accessibilityLabel(Text("Error"))`, which **replaces** the visible text as the accessibility label. The typed `failure` parameter is never used.
- **Why it is a UX problem:** VoiceOver users hear only "Error". No user learns what failed. The typed failure is present in state (e.g. `RepositoryError`, `ApplicationValidationError`) but is dropped at the presentation boundary — the opposite of ARC-001's "presented as it is, never silent".
- **Recommended fix:** Remove the `.accessibilityLabel` override; render a human-readable message derived from the typed failure (never the raw secret, ARC-005); set an accessibility label that includes the message. If a generic message is kept, it must remain the accessibility label's content.
- **Acceptance criteria:**
  - VoiceOver announces the actual failure message, not just "Error".
  - The visible banner text is not replaced by an unrelated label.
  - Typed failures map to user-meaningful strings; credential detail never appears.

#### A3 — Inconsistent VoiceOver grouping of message bubbles (P2)

- **File/symbol:** `ConversationScreenView.swift:68-97` (`messageBubble`, `bubbleContent`) vs `:99-116` (`assistantBubble`).
- **Current behavior:** History bubbles apply `.accessibilityLabel("User message"/"Assistant message")` to a container whose children remain separate elements (`MarkdownView` uses `.accessibilityElement(children: .contain)`, `MarkdownView.swift:35`). The streaming/interrupted bubble applies `.accessibilityElement(children: .combine)` plus a label.
- **Why it is a UX problem:** VoiceOver interaction differs per message type; a chat message should be read as one logical element (role, then content) every time.
- **Recommended fix:** Use one consistent strategy (`.combine`) for all message bubbles, with a label composed of role and content.
- **Acceptance criteria:** VoiceOver reads every message bubble as one logical element — role followed by content — consistently for user, assistant, and streaming/interrupted messages.

#### A4 — No streaming announcement or progress affordance (P2)

- **File/symbol:** `ConversationScreenView.swift:42-64` (`streamingBubble`), `:146-151` (`isStreaming`).
- **Current behavior:** Partial content re-renders on every delta; the only indication of activity is the composer's Stop button. No accessibility announcement fires when a response starts, updates, or ends.
- **Why it is a UX problem:** VoiceOver users get no feedback that a response is forming versus finished; sighted users get no "responding" indicator.
- **Recommended fix:** Post an accessibility announcement on streaming start/completion/interruption; add a visible "Responding…" status; keep the Stop affordance.
- **Acceptance criteria:** An accessibility announcement fires when streaming starts and completes or is interrupted; a visible responding indicator exists; content remains selectable.

#### A5 — Hardcoded user-facing strings (P2)

- **File/symbol:** every view file in `OmniaPresentation` and the shells' `LaunchFailureView` (`OmniaAppExecutable.swift:99-115`, iOS host `OmniaiOSApp.swift`).
- **Current behavior:** All user-visible text is a hardcoded English `String`/`Text` literal (e.g. "No Provider Connections", "Remove", "Reset", "Try Again").
- **Why it is a UX problem:** Violates UI.md §Localization. Non-English locales are impossible; strings are duplicated across three banners and two shells.
- **Recommended fix:** Adopt `String(localized:)`/localization catalog per UI.md. Already recorded as a follow-up in `PROJECT_STATE.md` next_tasks — this audit confirms the scope spans every view plus the shell.
- **Acceptance criteria:** All user-visible strings move to a localization catalog; a non-English locale renders without hardcoded fallbacks.

### Usability

#### U1 — No Return-key send and no keyboard shortcut (P1)

- **File/symbol:** `ConversationScreenView.swift:118-144` (`composer` `TextField`).
- **Current behavior:** The message `TextField` has no `.onSubmit`, `.submitLabel`, or `.keyboardShortcut`. `grep` confirms no `onSubmit`/`keyboardShortcut` anywhere in the package or app.
- **Why it is a UX problem:** Keyboard users cannot send with Return (macOS hardware keyboard, iOS return key); full-keyboard-access users have no path but the on-screen button.
- **Recommended fix:** `.onSubmit { submit() }` with `.submitLabel(.send)`; on macOS add a keyboard shortcut (e.g. Command+Return).
- **Acceptance criteria:** Return sends on both platforms; an empty/whitespace draft is still disabled; the Stop button still takes over while streaming.

#### U2 — No auto-scroll to the newest content (P1)

- **File/symbol:** `ConversationScreenView.swift:42-49` (`ScrollView`/`LazyVStack`).
- **Current behavior:** No `ScrollViewReader`/`scrollTo`. New messages and streaming deltas are appended below the fold.
- **Why it is a UX problem:** In a chat this is the core affordance — the newest content is invisible in any non-trivial conversation, and streaming output renders out of view.
- **Recommended fix:** Add a `ScrollViewReader`; scroll to the latest message on send and on each streaming update (anchoring to the bottom only when the user is near it, with a "jump to latest" affordance when they scroll up).
- **Acceptance criteria:** The view scrolls to the latest message on send and on streaming append; manual upward scrolling is not overridden; an explicit jump-to-latest control appears when scrolled up.

#### U3 — Configure form discards all input on a failed save (P1)

- **File/symbol:** `RootView.swift:336-345` (`configure`), `:376-389` (`failingSettingsState`), `ProviderConnectionFormView.swift:96-113` (`submit`).
- **Current behavior:** On failure, `failingSettingsState` sets `isComposing: false`, dismissing the form, and `submit()` clears the credential field. All `@State` field values live in the freshly-created view and are lost.
- **Why it is a UX problem:** The endpoint is validated only at the service boundary as an absolute `http`/`https` URL (`ProviderConnectionService.validatedEndpoint`). A user typing e.g. `localhost:8080` gets the whole declaration — display name, capabilities, limits, version, endpoint — wiped after a single failure, in the primary first-run setup flow.
- **Recommended fix:** On failure, keep `isComposing: true` and show the failure inside the form; retain all field values; validate endpoint and numeric fields inline before submit (see U8).
- **Acceptance criteria:** A failed configure keeps the form open with its input; an inline, user-meaningful error is shown; the credential field is cleared per ARC-005 but other fields are retained.

#### U4 — Unsent draft is not preserved across navigation; `state.draft` is dead (P2)

- **File/symbol:** `ConversationScreenView.swift:26` (`@State private var draft`), `:118-144` (`composer`); `ConversationScreenState.swift:64-65, 83` (`draft`).
- **Current behavior:** The view owns its own `@State draft`; `ConversationScreenState.draft` is declared but never rendered (`grep` shows the only reference is its own initializer). Popping and reopening a conversation builds a new view, so the draft resets to empty.
- **Why it is a UX problem:** An in-progress message is silently lost when the user leaves and returns; the frozen state model declares a field the layer ignores.
- **Recommended fix:** Render the draft from state via a binding (keep the field in the model) or rehydrate the local draft when the same conversation is reopened.
- **Acceptance criteria:** An unsent draft survives leaving and returning to a conversation; either `state.draft` reflects the rendered draft or the field is removed through a spec revision.

#### U5 — Destructive actions with no confirmation or undo (P2)

- **File/symbol:** `ConversationListView.swift:93-99`, `SettingsView.swift:116-122` (`allowsFullSwipe: true`).
- **Current behavior:** A full swipe deletes a conversation or removes a provider connection (and its stored credential, ARC-005) immediately, with no confirmation and no undo.
- **Why it is a UX problem:** Full-swipe mis-taps are irreversible and destroy user content; removing a provider also discards the Keychain credential.
- **Recommended fix:** Remove `allowsFullSwipe` or confirm the destructive action (`.confirmationDialog` for context-menu/accessibility paths; an alert or undo for the swipe path).
- **Acceptance criteria:** Deleting/removing requires a confirming step or offers undo; accidental full-swipe no longer destroys content.

#### U6 — Empty-state flash before the first load completes (P2)

- **File/symbol:** `RootView.swift:64` (`listState ?? ConversationListState(items: [])`), `:151` (`settingsState ?? SettingsState(connections: [], configuration: [])`).
- **Current behavior:** While `listState`/`settingsState` are `nil`, the views render an empty list/settings with the empty-state overlay; the async load then replaces it.
- **Why it is a UX problem:** On every launch the app briefly shows "No Conversations"/"No Provider Connections" even when content exists — misleading on slow storage and on every cold start.
- **Recommended fix:** Distinguish "loading" (`nil`) from "loaded and empty"; render a `ProgressView` (as the shells already do for launch) while `nil`.
- **Acceptance criteria:** No empty-state flash; a loading state is shown until the first load resolves.

#### U7 — No retry or re-edit path for failed states (P2)

- **File/symbol:** `SettingsView.swift:104-123` (`connectionRow`), `ConversationScreenView.swift:58-64` (`streamingBubble` `.interrupted`).
- **Current behavior:** A provider row in `.unavailable`/`.disabled` offers only Remove — no detail, no retry, no endpoint edit. An interrupted assistant response offers only manual copy-and-resend; there is no Retry/Continue.
- **Why it is a UX problem:** Transient failures are not recoverable without destructive action or re-typing.
- **Recommended fix:** Add a Retry intent for interrupted responses (re-send the last prompt against the preserved partial content) and a connection detail/edit affordance for non-ready providers.
- **Acceptance criteria:** An interrupted response can be retried/continued with one action; a non-ready provider connection offers a way to retry or edit instead of only Remove.

#### U8 — No inline validation; silent numeric coercion; wrong keyboards (P2)

- **File/symbol:** `ProviderConnectionFormView.swift:96-121` (`submit`, `canSubmit`), `:71-77` (version `TextField`s), `:69-70` (limits `TextField`).
- **Current behavior:** `canSubmit` checks only display name, capabilities, endpoint, and credential. Non-numeric limits become `nil` silently (`Int(maxRequestsPerMinute)`); non-numeric versions become `0` (`Int(...) ?? 0`). There is no `.keyboardType(.numberPad/.URL)` and no autocorrection control.
- **Why it is a UX problem:** The user believes their limits and version were saved when they were silently coerced; iOS numeric and URL fields show the general keyboard.
- **Recommended fix:** Validate numeric fields (empty → nil, or require a non-negative integer), disable Save or show inline errors until valid; add `numberPad`/`URL` keyboards and disable autocorrection on endpoint and credential fields.
- **Acceptance criteria:** Non-numeric limits/versions block Save or show an inline error; a saved request never contains a silently coerced `0`/`nil`; iOS shows appropriate keyboards.

#### U9 — Single-line composer only (P2)

- **File/symbol:** `ConversationScreenView.swift:118-144` (`composer` `TextField`).
- **Current behavior:** The composer is a single-line `TextField`; multi-line drafts are impossible.
- **Why it is a UX problem:** Structured or long messages cannot be composed.
- **Recommended fix:** A `TextEditor` or `TextField(axis: .vertical)` with a height cap, growing with content; keep Return-to-send (U1) with Shift+Return for newline on macOS.
- **Acceptance criteria:** Multi-line drafts are possible; the composer grows to a cap; Return still sends.

### State Management

#### S1 — Unexpected stream errors are silently swallowed (P1)

- **File/symbol:** `RootView.swift:284-287` (`send` catch), `ConversationScreenSurface.swift:134-145` (`send`).
- **Current behavior:** Typed failures (`ApplicationValidationError`, `RepositoryError`, `CapabilityError`, `CredentialStorageError`) are correctly yielded as a failure state. Unexpected errors are rethrown, caught in `RootView.send`, and handled by `reloadPresentedConversation()` with **no failure state set** — the user sees only the (possibly empty) interrupted bubble.
- **Why it is a UX problem:** The user cannot distinguish "I stopped it" from "it failed"; ARC-001's "never silent" is violated for the unexpected path, and no retry is offered.
- **Recommended fix:** On an unexpected error, set a terminal failure state on `screenState` (in addition to reloading), so the interruption reason is visible and distinct from user-initiated cancellation.
- **Acceptance criteria:** An unexpected stream error renders a failure on the screen; partial content remains visible; no silent failure path remains.

#### S2 — Failure detail dropped at the banner (P1)

- Merged with A2: the typed failure is carried by state but discarded by the banner in all three views. Fix together with A2.

#### S3 — Back-stack is not modeled; route restoration relies on the container (P2)

- **File/symbol:** `RootView.swift:69-89, 118-134` (`destination` binding), `NavigationState.swift:15-33` (single `currentRoute`).
- **Current behavior:** `NavigationState` models only the current route; the pushed stack is implicit in `NavigationStack`, and the bridging binding maps `nil → .conversationList`.
- **Why it is a UX problem:** Correct today for a one-deep stack, but the model cannot express a path stack, so scene re-activation/deep-linking cannot restore a stack, and the system back button semantics are not represented in the frozen model.
- **Recommended fix:** Record the decision in DES-012 §3.5 review notes; only if a second-level navigation need appears, revise the model to a path array through a spec revision.
- **Acceptance criteria:** Popping always returns to the conversation list; scene re-activation restores the current route; the modeling decision is documented.

### Visual Consistency

#### V1 — Hardcoded bubble colors and fixed padding not validated against system settings (P2)

- **File/symbol:** `ConversationScreenView.swift:87-97` (`bubbleContent`), `:118-144` (`composer`).
- **Current behavior:** User bubbles use `Color.accentColor` with `Color.white` text; all bubbles use `Color.secondary.opacity(0.12)` backgrounds and fixed `.padding(10)`.
- **Why it is a UX problem:** White-on-accent can fail WCAG AA with light or custom accents; fixed paddings do not scale with Dynamic Type; no increased-contrast handling.
- **Recommended fix:** Use semantic colors and Dynamic Type-aware insets; verify contrast in light/dark and increased-contrast modes.
- **Acceptance criteria:** Bubbles meet WCAG AA in light and dark modes and increased contrast; Dynamic Type at largest size is legible.

#### V2 — Duplicated per-view styling; no design tokens (P2)

- **File/symbol:** `failureBanner` in three views, empty states in two views, toolbar labels in all views.
- **Current behavior:** Identical banner/empty-state markup is re-declared per view (`.ai/standards/UI.md` §Design System is Draft; tokens are not yet applied).
- **Why it is a UX problem:** Drift risk; visual inconsistency evolves as views change independently.
- **Recommended fix:** Introduce shared presentation components (e.g. `ErrorBanner`, `EmptyStateView`) or token-backed styling when the design system moves past Draft.
- **Acceptance criteria:** Banner/empty-state styling is shared or tokenized; no per-view divergence.

#### V3 — iOS orientation is undeclared (build warning) (P2)

- **File/symbol:** `App/Omnia.xcodeproj/project.pbxproj` (OmniaiOS target build settings; `INFOPLIST_KEY_UILaunchScreen_Generation = YES` with no `UISupportedInterfaceOrientations`/`INFOPLIST_KEY_UISupportedInterfaceOrientations`); `App/OmniaiOS/` has no Info.plist.
- **Current behavior:** The iOS build emits "All interface orientations must be supported unless the app requires full screen"; rotation behavior is undefined on iPhone.
- **Why it is a UX problem:** A chat app typically locks portrait on iPhone; the warning indicates an incomplete declaration that could surprise users on iPad and iPhone.
- **Recommended fix:** Declare orientations (portrait for iPhone, all for iPad) in the iOS target settings or a generated Info.plist.
- **Acceptance criteria:** The iOS build has no orientation warning; rotation behaves as declared on iPhone and iPad.

#### V4 — Raw error string presented on launch failure (P2)

- **File/symbol:** `OmniaAppExecutable.swift:69-91, 99-115` (`launch`, `LaunchFailureView`), iOS host equivalent.
- **Current behavior:** `launchFailure = String(describing: error)` is rendered verbatim as the failure message.
- **Why it is a UX problem:** Raw Swift error descriptions are not user-facing copy; they can be long and technical.
- **Recommended fix:** Map launch failures to a concise, user-meaningful message with the existing "Try Again"; keep details in logs.
- **Acceptance criteria:** Launch failure shows concise human-readable copy; details are not shown verbatim; retry still re-runs.

#### V5 — No navigation title on the conversation list root (P3)

- **File/symbol:** `ConversationListView.swift:43-67` (no `.navigationTitle`); `RootView.swift:142` (title set only on the conversation screen).
- **Current behavior:** The root screen has no title; the iOS back-button label on the pushed conversation screen derives from an empty title.
- **Why it is a UX problem:** Minor; the root lacks identity and the back label may be empty/odd.
- **Recommended fix:** `.navigationTitle("Conversations")` on the list.
- **Acceptance criteria:** The root shows a title; the iOS back button is labeled from it.

## Findings Not Listed in Issue #154

The following were found during the audit beyond the seed list in the issue: **U3** (form data loss on failed save), **U4** (draft loss / dead `state.draft`), **U5** (no confirmation or undo), **U7** (no retry/re-edit path), **U8** (silent numeric coercion and wrong keyboards), **U9** (single-line composer), **S3** (back-stack not modeled), **V3** (iOS orientation undeclared), **V4** (raw launch error string), **V5** (missing root title).

## Prioritized Implementation Order for the Next UX Sprint

Phase 1 — P1, core-flow correctness, smallest surface first:

1. **U2** — Auto-scroll to latest content (`ConversationScreenView`).
2. **U1** — Return-key send + macOS keyboard shortcut (`ConversationScreenView`).
3. **U3** — Retain configure-form input on failure + inline validation (`RootView`, `ProviderConnectionFormView`).
4. **A1** — macOS context-menu Delete/Remove for rows (`ConversationListView`, `SettingsView`).
5. **A2/S2** — Failure banners: present typed failure text + real accessibility label (all three views).
6. **S1** — Surface unexpected stream errors as a terminal failure (`RootView`, `ConversationScreenSurface`).

Phase 2 — P2, quality and consistency:

7. **U5** — Confirmation/undo for destructive actions.
8. **U8** — Numeric/URL validation + iOS keyboards in the configure form.
9. **U4** — Draft preservation; reconcile `state.draft`.
10. **A3** — Consistent bubble accessibility grouping.
11. **A4** — Streaming announcements and responding indicator.
12. **U6** — Loading state distinct from empty state.
13. **U7** — Retry/continue for interrupted responses and non-ready providers.
14. **V1** — Semantic colors, contrast, Dynamic Type.
15. **V3** — iOS orientation declaration.
16. **V4** — Launch-failure copy.
17. **V2** — Shared banner/empty-state components or tokens.

Phase 3 — P2/P3, polish and backlog:

18. **A5** — Localization of all user-visible strings (existing follow-up).
19. **U9** — Multi-line composer.
20. **V5** — Conversation-list root title.
21. **S3** — Navigation-stack modeling decision recorded.

## Recommended Next Issues

Each maps to a template and the correct single `type:*`/`layer:*`/`priority:*` labels; created per the create-issue workflow.

| Priority | Type | Layer | Title |
| --- | --- | --- | --- |
| high | feature | presentation | Conversation screen: auto-scroll to latest and Return-to-send |
| high | bug | presentation | Configure form discards all input when a save fails |
| high | feature | presentation | macOS context-menu actions for conversation and provider rows |
| high | bug | presentation | Failure banners drop the typed error and announce only "Error" |
| high | bug | presentation | Unexpected stream errors are silently swallowed |
| medium | feature | presentation | Confirmation/undo for destructive row actions |
| medium | feature | presentation | Provider form numeric/URL validation and iOS keyboards |
| medium | feature | presentation | Preserve the unsent draft across navigation |
| medium | feature | presentation | Loading state distinct from the empty state |
| medium | feature | presentation | Streaming accessibility announcements and responding indicator |
| medium | feature | presentation | Retry/continue for interrupted responses; provider edit affordance |
| medium | feature | presentation | Semantic colors, contrast, and Dynamic Type support |
| low | bug | infrastructure | Declare iOS supported orientations (silence the build warning) |
| low | feature | presentation | Localize all user-visible strings |

## Implementation Status

Phase 1 of the [prioritized implementation order](#prioritized-implementation-order-for-the-next-ux-sprint) is implemented (2026-08-07), and the Phase 2 items **U5** (confirmation for destructive actions), **U8** (configure-form validation and keyboards), **U4** (draft preservation), **A3** (consistent bubble accessibility), **A4** (streaming announcements and responding indicator), **U6** (loading state distinct from empty state), and **U7** (retry/continue for interrupted responses; provider endpoint edit), and **V1** (semantic colors, contrast, Dynamic Type) are implemented (2026-08-07). Each item cites the file/symbol changed and how the acceptance criteria are met. The SwiftUI view layer is Apple-platform code isolated behind `canImport(SwiftUI)` and is not exercised by the Linux test environment (DES-012 §3.7); the changes were parse-checked and reviewed against `.ai/standards/UI.md` on the Linux build environment, and a macOS physical launch verification remains pending per DES-013 §3.6.

### Phase 1 — Implemented

| Item | Status | Implementation |
| --- | --- | --- |
| **U2** — Auto-scroll to latest content | Implemented | `ConversationScreenView.swift`: `ScrollViewReader` with a bottom marker (`bottomMarker`, anchored `conversation-screen-bottom`); a `BottomMarkerPosition` preference and `ScrollViewportSize` preference drive `isNearBottom`, so streaming appends auto-scroll only while the user is reading the newest content; a manual scroll upward is never overridden; a Jump to Latest control appears in an `.overlay` when scrolled up. |
| **U1** — Return-key send + macOS shortcut | Implemented | `ConversationScreenView.swift` composer: `.onSubmit(submit)` + `.submitLabel(.send)`; the send button carries `.keyboardShortcut(.return, modifiers: .command)` (Command+Return on macOS). Both route through one guarded `submit()`: an empty/whitespace draft is not sent, and the Stop affordance takes over while streaming. |
| **U3** — Retain configure-form input on failure | Implemented | `RootView.swift` `failingSettingsState` preserves `isComposing`, so a failed configure keeps `ProviderConnectionFormView` mounted with all `@State` fields retained; `SettingsView.swift` presents the failure banner above the form; the credential field is still cleared on submit per ARC-005. |
| **A1** — macOS context-menu Delete/Remove | Implemented | `ConversationListView.swift` and `SettingsView.swift`: `.contextMenu` with a destructive Delete/Remove button on conversation and provider-connection rows; iOS swipe removal is unchanged. |
| **A2/S2** — Failure banners present typed failure text | Implemented | All three views' `failureBanner` now render user-meaningful copy derived from the typed failure through the shared `FailureCopy` helper (in `ConversationScreenView.swift`), and the accessibility label carries the message instead of the fixed "Error". Copy maps `RepositoryError`, `ApplicationValidationError` reasons, `CapabilityError`, and `CredentialStorageError`; no raw error detail is ever presented (ARC-005). |
| **S1** — Surface unexpected stream errors | Implemented | `RootView.swift` `send` catch now calls `presentUnexpectedStreamFailure()`, which reloads the conversation and sets a terminal `.unexpected` failure on `screenState`; `ConversationScreenState.swift` gained the additive `.unexpected` case on `Failure` (DES-012 §3.2), covered by new Linux tests in `ConversationScreenStateTests.swift`. |

### Phase 2 — Implemented (U5, U8, U4, A3, A4, U6, U7)

| Item | Status | Implementation |
| --- | --- | --- |
| **U5** — Confirmation for destructive actions | Implemented | `ConversationListView.swift` and `SettingsView.swift`: the context-menu and swipe Delete/Remove actions no longer destroy immediately — they set a pending-deletion/removal state that presents the system `.confirmationDialog` with a `.destructive` confirm button whose message states the consequence (the provider message names the stored credential, ARC-005); `allowsFullSwipe` is removed so a full swipe never triggers the destructive action. The confirm step is the native system dialog — explicit and accessible (VoiceOver, full keyboard access on macOS). The delete/remove intent is unchanged and still translated by the frozen surfaces (DES-012 §3.3, §3.4; ARC-002). |
| **U8** — Inline numeric/URL validation + iOS keyboards | Implemented | `ProviderConnectionFormView.swift`: numeric fields are validated before Save — the limit parses to a non-negative `Int` (empty means no limit, mapped to `nil` per the frozen `ProviderLimits`), and each version part must be a non-negative `Int` (the frozen `SemanticVersion` has no empty form, so empty text is never coerced to `0`); `canSubmit` includes `limitIsValid && versionIsValid`, and inline caption errors render under the Limits and Version sections when invalid, so a saved `ConfigureProviderRequest` never contains a silently coerced `0`/`nil`. The Endpoint field uses `.keyboardType(.URL)` and the numeric fields `.keyboardType(.numberPad)`, with autocorrection disabled and autocapitalization off on the Endpoint and API Key fields, so iOS shows the appropriate keyboards. |
| **U4** — Draft preservation / reconcile `state.draft` | Implemented | The dead `ConversationScreenState.draft` field is now the rendered draft: `ConversationScreenView` renders it through a `@Binding` instead of transient `@State` (the composer edits `state.draft` directly), and `RootView` records the in-progress draft per conversation in a `conversationDrafts` store, rehydrates it into `screenState.draft` when a conversation is opened (create/select/terminal failure reload), preserves it through streaming updates (`send` merges it into each rendered state), and clears it on conversation delete; `ConversationScreenState.replacingDraft(_:)` is the additive copy helper, covered by new Linux tests. Acceptance criteria met: an unsent draft survives leaving and returning to a conversation, and `state.draft` reflects the rendered draft. |
| **A3** — Consistent bubble accessibility grouping | Implemented | `ConversationScreenView.swift`: every message bubble — history user/assistant and streaming/interrupted — now uses one strategy, `.accessibilityElement(children: .combine)`, with a label composed of the role followed by the content (`messageAccessibilityLabel`, `assistantAccessibilityLabel`); the label's content is the plain-text reading of the markdown (`accessibilityText` strips inline markdown like `MarkdownView` renders it, code content verbatim). Previously the history bubbles kept `MarkdownView`'s `.contain` children as separate elements and the streaming bubble's explicit label replaced its content, so VoiceOver grouping and reading differed per message type. Acceptance criteria met: VoiceOver reads every message bubble as one logical element — role followed by content — consistently for user, assistant, and streaming/interrupted messages. |

| **A4** — Streaming announcements and responding indicator | Implemented | `ConversationScreenView.swift` posts an accessibility announcement on the stream lifecycle — `announceStreamingTransition(from:to:)` announces "Assistant is responding." on streaming start, "Response complete." on completion, "Response interrupted." on interruption, and the banner's failure message when an active stream ends in a typed failure (never silent, ARC-001); content deltas continue without re-announcing (`previousStreamingCondition`). The announcement is posted without moving the focus or affecting selection (`announce(_:)`: `UIAccessibility.post(notification: .announcement, ...)` on iOS, `NSAccessibility.post(element: ..., notification: .announcementRequested, userInfo: [.announcement:, .priority: ...])` on macOS). The composer shows a visible "Responding…" status next to the Stop button while a stream is active. A user-initiated stop also announces the interruption: `RootView.cancel()` renders the state the Domain preserved as the interrupted condition via the new `ConversationScreenState.replacingStreamingCondition(_:)` (covered by new Linux tests), so the partial content is presented as incomplete, never discarded (ARC-001), and the Stop affordance gives way to the composer. Acceptance criteria met: an accessibility announcement fires when streaming starts and completes or is interrupted, a visible responding indicator exists, and content remains selectable. |

| **U6** — Loading state distinct from empty state | Implemented | `RootView.swift`: while the conversation list or the settings state is `nil` — the first load has not resolved — the shell renders a centered `ProgressView` (`loadingState`, the same pattern as the shells' launch loading) instead of an empty `ConversationListState(items: [])` / `SettingsState(connections: [], configuration: [])`, so no "No Conversations"/"No Provider Connections" empty-state flash appears before content loads; the loaded-but-empty state still shows the empty-state overlay, and reloads keep the previously rendered state so nothing flashes. Acceptance criteria met: no empty-state flash, and a loading state is shown until the first load resolves. |

| **U7** — Retry/continue for interrupted responses; provider endpoint edit | Implemented | **Interrupted responses.** `SendMessageUseCase.resume(_:)` (OmniaApplication, DES-011 §3.3) resumes the interrupted stream of a conversation: the preserved partial content is carried forward into the reply, no user message is appended (the last prompt is already in the preserved history), the completed reply is assembled and persisted, and a second interruption preserves the content again — never discarded (ARC-001, DES-009 §3.3, §3.11.4); a conversation that is not stored or is not marked interrupted is rejected with the typed `ApplicationValidationError`, and a failed provider selection surfaces as the Domain `CapabilityError.providerUnavailable`. `ConversationScreenSurface.resume(_:from:rendering:)` renders the resumed flow as `ConversationScreenState`, accumulating the deltas onto the carried partial content (`startingPartial`) and reconciling an interruption's reported partial onto the accumulated content, so a subsequent retry seeds from the full preserved content; the `resume` flow is covered by 6 new Linux use-case tests and 3 new Linux surface tests. `ConversationScreenView` presents the interrupted bubble's one-action Retry (Continue) affordance, and `RootView.retry()` translates it — the retry continues the interrupted response with one action. **Non-ready providers.** `SettingsView.connectionRow` now offers "Edit Endpoint…" in the row context menu alongside Remove (uniform, provider-independent, ARC-004); the endpoint editor — the new `ProviderEndpointEditorView`, presented on the additive `SettingsState.Editing` condition — is pre-filled with the recorded endpoint (resolved through the new `SettingsSurface.endpoint(for:)`) and edits only the endpoint through the new `SettingsSurface.updateEndpoint(_:for:)`, which records it through the frozen `ProviderConnectionService.updateEndpoint(_:for:)` (DES-011 §3.9) — a malformed endpoint surfaces as the typed `ApplicationValidationError`, and a failed update keeps the editor open with its input retained (`RootView.failingSettingsState` preserves the edit condition), never silent (ARC-001). The endpoint surface is covered by 7 new Linux `SettingsSurface` tests and the edit condition by 5 new Linux `SettingsState` tests. Acceptance criteria met: an interrupted response can be retried/continued with one action, and a non-ready provider connection offers a way to edit instead of only Remove. |

### Phase 2 — Implemented (V1)

| Item | Status | Implementation |
| --- | --- | --- |
| **V1** — Semantic colors, contrast, Dynamic Type | Implemented | `ConversationScreenView.swift` and the new platform-independent `BubbleTextColor` (covered by new Linux tests in `BubbleTextColorTests.swift`, DES-012 §3.7): the user bubble no longer renders fixed white text on `Color.accentColor` — `userBubbleTextColor()` resolves the accent's sRGB components (`UIColor(Color.accentColor)` / `NSColor(Color.accentColor)`) and picks the higher-contrast of white and black by WCAG relative luminance, so the default light accent (#007AFF, ≈ 4.0:1 with white — below AA) and the dark accent (#0A84FF) now choose black and meet WCAG AA (≥ 4.5:1), and any custom accent is handled the same way in light, dark, and increased-contrast mode; the bubble and composer insets are Dynamic Type-scaled through `@ScaledMetric(relativeTo: .body)` `bubblePadding`, so the largest accessibility size stays legible. Acceptance criteria met: bubbles meet WCAG AA in light and dark mode and increased contrast, and Dynamic Type at the largest size is legible. |

### Phase 2 and Phase 3 — Pending

Items 15–17 (Phase 2) and 18–21 (Phase 3) of the prioritized implementation order are not yet implemented; they remain the recommended next issues above.

## Related Documents

- Product Charter: `Documentation/Product/PRODUCT_CHARTER.md`
- UI Standard: `.ai/standards/UI.md`
- Presentation contract: `Documentation/Design/PRESENTATION_API.md` (DES-012)
- App contract: `Documentation/Design/APP_API.md` (DES-013)
- Architecture: `Documentation/Architecture/` (ARC-001, ARC-002, ARC-005, ARC-006, ARC-007, ARC-009, ADR-0001)
- Audit issue: GitHub issue #154
