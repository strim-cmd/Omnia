# UI Redesign V2 Plan - Modern AI Client Style

## Objective
Redesign the `Omnia` iOS UI to match the modern AI client aesthetic (Gemini/ChatGPT style) as per the design reference (`Design.png`), focusing on a "deep navy/black" dark theme with elevated surfaces and modern spacing.

## Design System Tokens (New)
I will introduce a `DesignTokens` object in `OmniaPresentation` to centralize:
- **Colors**:
    - `background`: Deep Navy/Black (`#050505` or similar)
    - `surface`: Elevated surface (`#1A1A1A`)
    - `accent`: Purple (`#8A2BE2`) and Cyan (`#00CED1`)
    - `textPrimary`: White, `textSecondary`: Gray
- **Radius**:
    - `container`: 20px
    - `bubble`: 16px
    - `composer`: 16px
- **Spacing**: Standardized spacing (8, 12, 16, 24).

## Component Redesign Plan

### 1. Conversation Screen (`ConversationScreenView`)
- **Composer**: Finalize the compact, dynamic-height design (1 line by default, max 4-6). Use elevated surface color, consistent radius.
- **Message Bubbles**: Apply elevation (surface color) for bubbles. Adjust spacing for better readability.
- **Header**: Clean up, align with new spacing/typography.
- **Provider Selector**: Refactor to fit the new card-like aesthetic.

### 2. Conversation List & Settings
- **Cards**: Implement consistent card styling (Background surface + radius + slight shadow).
- **Typography**: Apply standard font scales and weights to improve hierarchy.
- **Search**: Modernize the search bar to fit the list style.

### 3. States & Feedback
- **Empty/Loading/Error**: Consistent look and feel aligned with the new dark theme and surface colors.

## Verification
- Accessibility audit (VoiceOver, Dynamic Type).
- Keyboard handling (Composer resize, layout shift).
- Dark mode verification.
- Testing on iOS simulators (Portrait/Landscape).

## Reporting
I will produce `UI_REDESIGN_V2_REPORT.md` upon completion.
