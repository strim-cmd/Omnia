# Omnia UI — Components

This document defines reusable SwiftUI components visible in the supplied concept.

## ProviderSelector

Visual structure:
`[green status dot] ProviderName [chevron]`

Requirements:
- capsule shape
- dark/elevated background
- subtle border
- green status indicator for active provider
- compact typography
- tap target suitable for iOS

## PrimaryButton

Visual:
- purple filled surface
- white label
- rounded corners
- strong but restrained contrast

Use for primary actions only.

## SecondaryButton

Visual:
- elevated/dark surface
- thin border
- white/light label

## StatusPill

Examples from reference:
- `Active`
- `Default`

Active uses green semantic color.
Default is neutral.

## ChatMessageBubble

### User
- trailing alignment
- purple background
- white text
- rounded corners
- timestamp/check indicators below or within the bubble

### Assistant
- leading alignment
- elevated surface
- light text
- longer content allowed
- optional action row underneath:
  - copy
  - like
  - dislike
  - more

## ChatInput

Bottom composer consists of:
1. attachment button
2. text field
3. circular send button

Dark mode:
- input area is elevated against the background.
- send button is purple.
- placeholder is muted.

Light mode:
- same geometry and controls.
- neutral light surfaces.

## ThinkingState

Card shown while Omnia is thinking.

Reference:
- sparkle/AI icon
- title `Thinking`
- subtitle `Omnia is thinking`
- trailing activity indicator / dots

## StreamingState

Card shown while response is streaming.

Reference:
- sparkle/AI icon
- title `Streaming`
- subtitle `Omnia is typing`
- animated waveform/activity indicator

The animation should be subtle and should not alter layout.

## ErrorState

Reference:
- red error icon
- title `Error`
- explanatory message
- retry icon/button

Do not use a full-screen error unless the application cannot render the current screen.

## ConversationRow

Contains:
- conversation/chat icon
- title
- preview
- timestamp
- chevron

Grouped under:
- Today
- Yesterday
- Previous 7 Days

## ProviderCard

Contains:
- provider/status indicator
- provider name
- endpoint/subtitle
- status pill when active
- overflow menu

Active provider is visually distinguished.

## NavigationSidebar

Reference menu:
- New Chat
- Conversations
- Providers
- Settings
- About

Each row has:
- SF Symbol
- label
- selected state when applicable

## ThemeToggle

Compact card containing:
- moon icon
- `Dark Mode`
- toggle control

The supplied concept shows dark mode enabled.

## Logo

Omnia logo consists of a circular O-like mark with purple/cyan accent treatment.

If an existing Omnia logo asset exists in the project, reuse it.
Do not generate a replacement logo in code unless no asset exists.
