---
title: UI Standard
version: 0.1.0
status: Draft
---

# UI Standard

## Purpose

Define the user interface requirements so that Omnia always feels native, consistent, and accessible.

## Scope

All user interface work: SwiftUI views, screens, and interactions.

## Principles

- Follow the Apple Human Interface Guidelines.
- Prefer native SwiftUI components over custom ones.
- Match platform conventions for iOS, iPadOS, and macOS.
- The application must not look like a web app wrapped in a native shell.

## Design System

- The design system is in Draft status; see `Documentation/Design/`.
- Reuse existing components and tokens. Do not create ad-hoc styles.
- When the design system evolves, update the design documents first.

## Consistency

- Keep spacing, typography, colors, and icons consistent across screens.
- Respect system settings: dark mode, dynamic type, and reduced motion.

## Accessibility

- Every interactive element must be accessible.
- Provide appropriate labels, hints, and focus behavior.
- Support VoiceOver on iOS and iPadOS, and full keyboard access on macOS.

## Localization

- User-visible strings must be localized.
- Never hardcode user-facing text in view code.

## Related Documents

- `Documentation/Design/`
- `context/ARCHITECTURE.md`
- `standards/SWIFT.md`
