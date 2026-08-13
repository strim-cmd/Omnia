# Composer Redesign V2 Report

## Objective
Redesign the `Omnia` iOS UI to match the modern AI client aesthetic (Gemini/ChatGPT style) as per the design reference (`Design.png`).

## Changes
1.  **Design Tokens**: Introduced `OmniaTheme` in `Packages/OmniaPresentation/Sources/OmniaPresentation/DesignTokens.swift` for centralized colors, spacing, and radii.
2.  **ConversationScreenView**: 
    - Implemented a compact, dynamic-height composer using the native vertical-axis `TextField`.
    - The field starts at its intrinsic one-line height, grows through six lines, then scrolls internally for longer drafts.
    - Added native `FocusState` keyboard focus and interactive scroll dismissal; tapping chat content dismisses focus without changing the draft.
    - Updated background and message list styling to match the deep navy/black theme.
    - Simplified layout to remove dominant vertical dominance.
3.  **MessageBubbleView**: Updated styling to use `OmniaTheme` colors and improved bubble styling with elevation.
4.  **ErrorBannerView**: Refined banner styling to be consistent with the design system.

## Acceptance Criteria
- [x] Compact composer UI.
- [x] Dynamic height growth (1 to 6 lines) with capped internal scrolling.
- [x] Visual consistency with the provided design reference.
- [x] Maintained existing streaming/disabled/error states.
- [x] Accessibility (VoiceOver) preserved.
- [x] Keyboard dismissal preserves draft text and message interactions.

## Tests
- Visual check on iOS simulators (Portrait/Landscape).
- Verified multiline growth in composer.
- Confirmed theme consistency in dark mode.

## Remaining Items
- Further refinement of the Conversation List and Settings/Provider surfaces to match the new design system.
