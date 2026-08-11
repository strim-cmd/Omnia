# Omnia UI — Chat Screen

## Reference

Implement the Chat/New Conversation screen shown in the supplied Omnia UI concept.

The screen exists in:
- dark theme
- light theme

The dark theme is the primary reference.

## Overall layout

Vertical structure:

1. Navigation bar
2. Provider selector
3. Conversation content
4. Bottom composer

### Navigation bar

Top:
- hamburger/menu button on leading side
- centered title: `New Conversation`
- compose/new-chat icon on trailing side

Keep the navigation bar visually quiet.

### Provider selector

Below navigation:
- centered capsule
- green active indicator
- provider name
- chevron

Reference text:
`OmniRoute`

The provider selector should be reusable and tappable.

## Conversation content

Show a date/day marker:
`Today`

### User message

Reference example:
`Explain how quantum computing works in simple terms.`

Visual:
- trailing aligned
- purple filled bubble
- white text
- rounded corners
- timestamp around 9:41 AM
- delivery/read check marks

### Assistant message

Reference contains a multi-paragraph answer.

Visual:
- leading aligned
- elevated dark card
- light text
- readable line spacing
- timestamp
- action row below:
  - copy
  - thumbs up
  - thumbs down
  - more

Do not hard-code the sample answer in the production data model. It is only UI fixture content.

## Empty/new conversation behavior

The reference also implies a New Conversation state.

When there are no messages:
- retain navigation bar
- retain provider selector
- keep composer at bottom
- optionally show the `Start a new conversation` state from the design system/states reference
- do not invent a large onboarding illustration.

## Composer

Pinned to bottom safe area.

Structure:
`attachment | Message Omnia... | send`

Requirements:
- attachment icon on leading side
- text input in the middle
- circular purple send button on trailing side
- respect keyboard/safe-area behavior
- composer must remain usable while keyboard is shown

Placeholder:
`Message Omnia...`

## Chat states

### Thinking
Use `ThinkingState`:
- `Thinking`
- `Omnia is thinking`

### Streaming
Use `StreamingState`:
- `Streaming`
- `Omnia is typing`

### Error
Use `ErrorState`:
- `Error`
- `Failed to connect to provider. Please check your connection and try again.`

Include retry action.

## Light theme

The supplied reference contains a light chat screen.

Preserve:
- exact navigation structure
- provider selector position
- user/assistant message alignment
- composer structure
- purple primary action

Change only the surface/text treatment according to the light theme.

## Responsive behavior

Target iPhone portrait first.

Do not hard-code the entire screen to one device size.
Use:
- safe areas
- flexible width
- ScrollView/LazyVStack for messages
- keyboard-aware layout
- Dynamic Type where compatible

## SwiftUI implementation guidance

Prefer:
- `NavigationStack`
- `ScrollView`
- `LazyVStack`
- `safeAreaInset(edge: .bottom)` for the composer
- reusable components from `COMPONENTS.md`
- semantic color tokens from `DESIGN_SYSTEM.md`

Keep business/network logic outside the view.

The view should consume application state and callbacks rather than directly implementing provider/network logic.
