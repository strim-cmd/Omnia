# Changelog

This project follows Keep a Changelog and Semantic Versioning.

## [Unreleased]

## [1.0.1] - 2026-08-15

Hotfix for the v1.0 Gemini connection validation regression.

### Fixed

- Gemini Test Connection no longer rejects the canonical `models/<model>`
  model format the API returns and AI Studio shows: entering a model with
  the `models/` prefix failed with "Model unavailable" even when the
  endpoint and API key were valid. Connection validation now normalizes
  model names the same way the runtime request path does, so both
  `gemini-2.5-flash` and `models/gemini-2.5-flash` validate and route.

## [0.5.0] - 2026-08-07

The first distributable build (Beta v0.5 candidate): a native macOS and iOS
Omnia application with streaming conversations, provider connections, and a
reproducible release pipeline.

### Added

- Native macOS app (`Omnia`) with SwiftUI shell and sandbox entitlements.
- Minimal iOS host app (`OmniaiOS`).
- Conversation list with create, select, and delete; new conversations join the
  presented workspace.
- Conversation screen with the streaming send-message flow: deltas rendered
  incrementally, Markdown rendering and code-block presentation with preserved
  whitespace, and partial content preserved on interruption.
- Provider connection management: configure, list, and remove connections with
  the credential stored by reference in the platform Keychain and never rendered
  or logged.
- Configuration settings surface with typed values resolved across levels.
- Reproducible release pipeline: pinned Xcode, standard test suite across all
  six packages, macOS archive and unsigned DMG/zip packaging, and unsigned iOS
  IPA export for third-party signing.
- Omnia app icon for macOS and iOS from the provided design asset.

### Fixed

- Newly created conversations now join the presented workspace and appear in
  the list immediately and across relaunches (#150, #151).
- Streaming UTF-8 corruption: SSE bytes are buffered and only complete lines
  decoded (#148).
- CRLF line-end handling in streaming decode (#148).
- Release pipeline green on macOS 13 / iOS 16 deployment floor with unsigned
  IPA packaging (#148).

## [0.5.2] - 2026-08-09

Public repository release readiness. No product behavior or API changes.

### Added

- MIT license (`LICENSE`).
- Public repository security audit and release-readiness reports
  (`Documentation/Development/PUBLIC_REPOSITORY_SECURITY_AUDIT.md`,
  `PUBLIC_REPOSITORY_RELEASE_READINESS.md`, `PUBLIC_RELEASE_FINAL_CHECK.md`).
- README sections for project status, building and testing, and licensing.
- `.gitignore` entries for signing credentials and provisioning profiles.
- iOS build metadata (`INFOPLIST_KEY_UIApplicationSceneManifest_Generation`) so
  the SwiftUI entry point launches on device.
- `#if canImport(SwiftUI)` guard so the design-token color API builds on Linux.

### Changed

- The release pipeline's iOS signing and export steps now run only when the
  corresponding distribution credentials are configured; a credential-free run
  still builds and packages unsigned artifacts.
- Internal and private development references removed or genericized across the
  documentation, issue templates, and source comments.

### Fixed

- Removed an unused `import OmniaTheme` so the conversation screen builds on
  Linux.

## [1.0.0] - 2026-08-15

The first v1 release: provider/model discovery and defaults, capability-aware
multimodal input, durable conversation management, production Markdown and
recovery UX, and first-launch/data-safety polish over the stable generation
lifecycle.

### Added

- Provider-scoped model discovery, cached fallback, coherent global defaults,
  per-conversation provider/model persistence, capability overrides, and a real
  Test Connection flow with redacted actionable errors.
- Gemini provider support: the Gemini (Generative Language API) family with its
  own client, mapping, provider adapter, and model inspector; a connection's API
  Type (OpenAI-compatible or Gemini) is selected when adding/editing a provider
  and recorded as typed connection configuration, and model discovery, Test
  Connection, and the runtime adapter binding route to the connection's family —
  connections configured before the API Type existed keep serving through the
  OpenAI-compatible default (ARC-004).
- Image, PDF, and plain-text attachment staging with count/size/capability
  validation, deterministic persistence, request resolution, history metadata,
  and deletion/orphan cleanup.
- Persistent conversation titles and timestamps, explicit rename precedence,
  local-time grouping/search/delete behavior, and safe Markdown rendering with
  fenced-code language labels, horizontal scrolling, links, and copy actions.
- Durable unsent text drafts keyed by conversation, restored across relaunch
  without a second conversation persistence source.
- First-launch Add Provider guidance and a coherent path from validated
  connection through default model to a usable chat.
- Settings routes for provider/credential management and confirmed Clear Data
  with explicit on-device scope.
- About now displays the real host-bundle version and build number.

- Providers and Settings are now distinct destinations: a dedicated Providers
  surface manages provider connections while Settings holds application settings,
  the navigation state carries each route, and the side drawer stays available on
  every pushed screen (UI issues 1, 2).
- Provider configuration uses one unified connection form for both adding and
  editing a connection, pre-filled with the connection's recorded declaration,
  endpoint, and model (UI issue 3).
- The provider add button is hidden while the connection form is open — compose
  or edit — so the screen never offers a second form next to the one shown (UI
  issue 4).
- Provider availability is driven by real lifecycle state: configure and update
  transition connections through the explicit lifecycle, the ready state is
  persisted and re-registered on launch, and the rendered availability reflects
  that state rather than configuration existence (UI issue 5).
- The message composer is adaptive: a compact single-line control that grows
  naturally with multi-line drafts instead of a permanently tall fixed area (UI
  issue 6).
- Dark Mode actually switches the interface between light and dark and persists
  through relaunches through the `appearance.darkMode` configuration key, which
  remains the single source of truth (UI issue 7).
- The conversation list presents its own header with the screen title; navigation
  between destinations is driven by the centralized navigation state and the side
  drawer (UX audit V5, S3).

- The conversation screen now lets you choose which configured provider connection serves a conversation: the provider selector — a native pull-down menu listing Automatic and each connection, with not-ready connections shown disabled — carries your explicit choice into the next message through the frozen selection request, honors the selection policy (a non-selectable choice is skipped and announced, never silently dropped), and preserves it across launches through the typed configuration (UX audit iteration V2).
- Shared presentation components (banner/empty-state markup) have been consolidated, ensuring visual consistency and reducing the risk of drift (UX audit V2).
- The iOS app now declares its supported interface orientations, so the build no longer warns and rotation behaves as intended: portrait on iPhone, and all orientations on iPad (UX audit V3).
- A failed launch (for example storage or credential storage being unavailable, or a configured provider failing to prepare) now presents concise, human-readable copy — never the raw Swift error description — with the unchanged retry action (UX audit V4).
- The conversation list now shows a navigation title, so the root has identity and the iOS back button is labeled correctly (UX audit V5).
- The navigation-stack modeling decision is recorded, confirming the current single-route model is sufficient for MVP v0.1 (UX audit S3).
- The message composer now supports multi-line drafts: the composer grows to a 6-line cap and preserves the Return-to-send behavior (UX audit U9).
- All user-visible strings are now localized: the presentation layer and shells use `String(localized:)` and localization catalogs, enabling non-English locales (UX audit A5).
- The message bubbles now meet WCAG AA contrast and stay legible at the
  largest Dynamic Type size: the user bubble's text color is chosen by WCAG
  relative luminance — the higher-contrast of white and black against the
  accent — instead of fixed white, and the bubble and composer insets scale
  with Dynamic Type (UX audit V1).
- An interrupted assistant response can now be continued with one action: the
  interrupted bubble's Retry (Continue) resumes the response through
  `SendMessageUseCase.resume`, carrying the preserved partial content forward
  into the reply — no duplicate user message is appended, the completed reply
  is persisted, and a second interruption preserves the content again, never
  discarded (UX audit U7).
- A provider connection row now offers an Edit Provider action alongside
  Remove: the unified connection form is pre-filled with the connection's
  recorded declaration, endpoint, and model, and saving records the change
  through the frozen provider surface — so a non-ready provider connection
  offers a way to edit instead of only Remove; a malformed value shows the typed
  failure and a failed update keeps the form open with its input retained (UX
  audit U7).
- VoiceOver now reads every message bubble — user, assistant, and
  streaming/interrupted — as one logical element with the role followed by the
  content, consistently (UX audit A3).
- An accessibility announcement now fires when a response starts, completes, or
  is interrupted, and a visible "Responding…" status appears next to the Stop
  button while a stream is active, so VoiceOver and sighted users both get
  feedback that a response is forming versus finished; stopping an active
  stream presents the preserved partial content as interrupted (UX audit A4).
- The conversation list and settings no longer flash their empty states before
  the first load resolves: a loading indicator is shown until the loaded
  content arrives, and the loaded-but-empty state still shows its empty-state
  message (UX audit U6).
- An unsent composer draft now survives leaving and returning to a
  conversation: the draft is rendered from the conversation state through a
  binding and preserved per conversation across navigation, streaming updates,
  and reopen (UX audit U4).
- The configure form now validates its numeric fields before saving: the limit
  must be empty or a non-negative whole number, and each version part must be a
  non-negative whole number, with inline error copy and Save disabled while
  invalid, so a saved request is never silently coerced to `0`/`nil`; the
  endpoint and numeric fields use the URL and number keyboards on iOS with
  autocorrection and autocapitalization off on the endpoint and API Key fields
  (UX audit U8).
- Deleting a conversation or removing a provider connection now requires an
  explicit confirming step: the context-menu and swipe Delete/Remove actions
  present a system confirmation dialog whose message states the consequence —
  including the stored credential on provider removal — and a full swipe no
  longer triggers the destructive action (UX audit U5).
- Auto-scroll to the newest content on the conversation screen: the view scrolls
  to the latest message on send and on streaming appends, only while the user is
  reading the newest content, with a Jump to Latest control when scrolled up
  (UX audit U2).
- Return-key send and Command+Return send on macOS for the message composer;
  while a stream is active the Stop affordance takes over (UX audit U1).
- macOS context-menu Delete/Remove on conversation and provider-connection
  rows; iOS swipe removal still works (UX audit A1).
- The typed failures the views present are rendered with user-meaningful copy,
  and the failure banners' accessibility labels carry the message instead of
  the fixed "Error" (UX audit A2/S2).
- Unexpected stream errors now present a terminal failure on the conversation
  screen — the interruption reason is visible and distinct from a user-initiated
  cancellation, never silent (UX audit S1).

### Fixed

- A failed provider configure keeps the connection form open with its input
  retained and shows the failure; only the credential field is cleared per
  ARC-005 (UX audit U3).
- Provider configure/remove operations roll back partial metadata, references,
  credentials, and lifecycle state instead of leaving selectable or orphaned
  records.
- Invalid saved defaults identify themselves and never silently redirect a new
  conversation to a different provider/model.
- Individually malformed conversation, provider, and workspace records are
  isolated during collection loads instead of making all valid data unreadable.

### Migration and Persistence

- Existing pre-v1 conversation/provider/workspace DTOs continue decoding with
  explicit defaults for v1 metadata; deterministic serializers remain the only
  source for accepted chat state.
- Interrupted/partial messages, attachment metadata/files, titles/timestamps,
  selections, defaults, appearance, and unsent drafts survive reload without
  duplication.
- Clear Data removes chats, attachments, settings, provider metadata, and the
  complete app-owned secure credential namespace while retaining an empty
  workspace shell for the running UI.

### Security

- API keys remain only in platform secure credential storage; provider and
  configuration JSON contain safe metadata and opaque references only.
- No analytics or remote telemetry was added. Logs, surfaced errors, fixtures,
  and diagnostics do not reveal credential or private conversation content.

### Known Limitations

- The release IPA is intentionally unsigned and requires external signing
  before installation; signing and App Store distribution are outside v1 scope.
- Physical-device checklist execution is pending a user-selected signed install.
- The short-prompt framework, prompt library, workspaces, plugins, voice, cloud
  sync, and built-in web/image generation remain post-v1 work.
