# Changelog

This project follows Keep a Changelog and Semantic Versioning.

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

## [Unreleased]

UX audit (issue #154) — core-flow correctness, accessibility, validation,
draft preservation, destructive-action protection, and retry/continue paths in
the presentation layer:

### Added

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
- A provider connection row now offers an Edit Endpoint action alongside
  Remove: the endpoint editor is pre-filled with the recorded endpoint and
  records the updated endpoint through the frozen provider endpoint surface,
  so a non-ready provider connection offers a way to retry or edit instead of
  only Remove; a malformed endpoint shows the typed failure and a failed update
  keeps the editor open with its input retained (UX audit U7).
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
