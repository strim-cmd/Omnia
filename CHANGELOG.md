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
