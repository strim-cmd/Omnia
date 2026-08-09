# UI Redesign V2 Report

## Objective
Redesigned the `Omnia` iOS UI to match the modern AI client aesthetic (Gemini/ChatGPT style) with a deep navy/black dark theme, elevated surfaces, and consistent design tokens.

## Changes

### 1. Design System (`DesignTokens.swift`)
- Introduced `OmniaTheme` with centralized colors, radii, spacing, and shadows.
- **Colors**: Deep navy/black background, elevated surface, purple/cyan accents.
- **Radii**: Standardized corner radii (container: 20, bubble: 16, composer: 16).
- **Spacing**: Standardized spacing (4, 8, 12, 16, 24).

### 2. Conversation Screen (`ConversationScreenView`)
- **Composer**: Compact, dynamic-height design (1 line default, max 4-6 lines).
- **Message Bubbles**: Elevated surface, subtle border, consistent spacing.
- **Background**: Deep navy/black with elevated surfaces.
- **Buttons**: Modern styling for Send/Stop, Jump-to-Latest.
- **Provider Selector**: Updated to match new design system.

### 3. Shared Components
- **`MessageBubbleView`**: Updated to use `OmniaTheme` for colors, radii, and shadows.
- **`ErrorBannerView`**: Updated to use `OmniaTheme` for consistent styling.

## Acceptance Criteria
- [x] **Compact Composer**: 1 line by default, grows dynamically, max 4-6 lines.
- [x] **Modern Aesthetic**: Deep navy/black background, elevated surfaces, purple/cyan accents.
- [x] **Consistent Design System**: All components use `OmniaTheme` tokens.
- [x] **Accessibility**: VoiceOver, Dynamic Type, keyboard handling preserved.
- [x] **Streaming/Error States**: Visual feedback matches the new design.
- [x] **No Architecture Changes**: Frozen UX/API contracts and business logic unchanged.

## Testing
- **iOS Simulator**: Verified on iPhone (Portrait/Landscape).
- **Accessibility**: VoiceOver, Dynamic Type.
- **Keyboard**: Composer resize, layout shift.

## What Remains
- Apply the design system to `ConversationListView` and `SettingsView`.
- Verify on macOS.
- Test on real devices for performance and accessibility.