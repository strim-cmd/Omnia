# Omnia UI — Design System

Status: Draft derived from the supplied Omnia UI concept image.
Platform: iOS / SwiftUI.
Primary visual direction: modern, minimal, dark-first, private/premium, restrained neon accents.

## 1. Design principles

- Dark theme is the primary presentation.
- UI uses near-black surfaces with subtle elevated surfaces and thin borders.
- Purple is the primary action/accent color.
- Cyan is the secondary accent.
- Green communicates healthy/active state.
- Red communicates errors.
- Components should feel compact and native to iOS rather than web-like.
- Avoid unnecessary gradients, shadows, decorative elements, and excessive borders.
- Preserve generous whitespace and strong hierarchy.
- Do not invent new navigation patterns when implementing the screens.

## 2. Color tokens

The supplied concept explicitly shows these values:

| Token | Hex | Usage |
|---|---|---|
| Primary | `#8A2BE2` | Primary buttons, active controls |
| Secondary | `#00D4FF` | Secondary accent / cyan highlights |
| Accent | `#7C3AED` | Accent surfaces/details |
| Success | `#22C55E` | Active/healthy status |
| Surface | `#0F1117` | Main dark background |
| Elevated | `#161A22` | Cards / elevated surfaces |
| Border | `#2A2F3A` | Subtle borders |
| Text | `#E5E7EB` | Primary text |

Use opacity variants of these tokens rather than introducing unrelated colors.

## 3. Typography

Reference concept:

- SF Pro Display for prominent headings.
- SF Pro Text for UI/body copy.
- Heading 1: 28pt / Bold.
- Heading 2/3: approximately 22pt / Semibold.
- Body: 16pt / Regular.
- Caption: 12pt / Regular.

Use Dynamic Type where practical, but keep the visual hierarchy close to the reference.

## 4. Geometry

Reference values should be treated as design targets, not pixel-perfect measurements:

- Card corner radius: approximately 12–16pt.
- Pills/capsules: fully rounded.
- Buttons: approximately 12–14pt radius unless circular.
- Thin borders: 1pt.
- Standard horizontal screen padding: approximately 16–20pt.
- Compact control spacing: 8pt.
- Standard component spacing: 12–16pt.
- Section spacing: 24–32pt.

## 5. Core components

### PrimaryButton
Purple filled button, white text, rounded corners.

### SecondaryButton
Dark/elevated surface with subtle border.

### ProviderSelector
Capsule containing:
- status dot
- provider name
- chevron

### StatusPill
Small capsule used for `Active`, `Default`, etc.

### MessageBubble
Two variants:
- user: trailing alignment, purple accent surface
- assistant: leading alignment, elevated dark surface

### InputField
Bottom chat composer:
- attachment button on leading side
- text input
- circular purple send button on trailing side

### IconButton
Compact transparent/dark control with SF Symbols.

### Card
Elevated dark surface, subtle border, rounded corners.

### ErrorCard
Dark/red-tinted card with:
- error icon
- title
- explanatory text
- retry action

## 6. Iconography

Use SF Symbols wherever possible.

Reference icon categories:
- menu
- compose
- chat
- providers/settings/about
- lock
- lightning
- target/circle
- information
- thumbs up/down
- copy
- more
- moon/sun
- check
- warning
- trash
- external link
- attachment
- send
- waveform/streaming

Do not replace SF Symbols with emoji.

## 7. Dark theme

Primary:
`#0F1117`

Elevated:
`#161A22`

Border:
`#2A2F3A`

Text:
`#E5E7EB`

Purple:
`#8A2BE2`

Cyan:
`#00D4FF`

Green:
`#22C55E`

## 8. Light theme

The concept contains a light chat screen. It should be implemented as a true theme rather than a separate visual design.

- Background: near-white.
- Cards/messages: light gray/white.
- Text: dark neutral.
- Keep the same purple primary action color.
- Preserve component geometry and hierarchy from dark mode.

## 9. Important implementation rule

The supplied image is a visual reference, not a source of exact runtime measurements.

When implementation details are not visible in the reference:
- prefer native iOS/SwiftUI conventions;
- keep the existing Omnia architecture;
- do not invent major features;
- do not change the product navigation model.
