---
title: UI Redesign Plan
document_id: UI-REDESIGN-001
version: 0.1.0
status: Draft
---

# UI Redesign Plan

## Purpose
Redesign the Omnia user interface to feel like a polished, modern AI client, inspired by apps like Gemini, while maintaining native platform behaviors and performance.

## Design Goals
- **Sleek & Modern:** Use clean layouts, ample whitespace, and subtle materials (backgrounds, blur effects).
- **Native Feel:** Ensure it feels like a genuine iOS/macOS app, not a web wrapper. Use standard SwiftUI controls, system fonts, and colors where appropriate.
- **Improved Hierarchy:** Clearer visual distinctions between lists, messages, and input controls.
- **Subtle Interactions:** Incorporate gentle animations (e.g., bubble entry, streaming text updates, transition transitions).

## Redesign Areas

### 1. Conversation List
- Refine row layout: use more modern spacing, larger titles, and subtle preview truncation.
- Improve visual hierarchy: distinguish between active conversations and empty states.
- Polish swipe actions and context menus to match modern HIG standards.

### 2. Conversation Screen
- **Message Bubbles:** Update bubble styling, possibly using subtle background materials, smoother corner radii (e.g., continuous rounded rectangles), and better contrast.
- **Streaming/Loading:** Ensure streaming feels fluid and responsive, not jarring.
- **Composer:** Refine input area, send button (e.g., icon and state transitions), and multi-line behavior.

### 3. Navigation & Header
- Standardize headers and navigation bar styles across the app (use large titles on iOS/macOS where appropriate).
- Ensure consistent spacing between the header, message list, and composer.

### 4. Visual Components
- Update `ErrorBannerView` and `EmptyStateView` for better integration into the new visual design.
- Refine button and input styling.

## Implementation Guidelines
- Preserve all existing UX audit behaviors (do not break UX/API contracts).
- Keep code clean and maintainable.
- Run tests regularly to ensure no regressions.
- Log every change in `Documentation/Development/UI_REDESIGN_LOG.md`.
