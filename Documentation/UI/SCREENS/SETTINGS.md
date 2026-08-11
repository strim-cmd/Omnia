# Omnia UI — Settings Screen

## Reference

Implement the Settings screen in the same design language as the rest of the
interface (new_design.md §9): never the standard iOS Form appearance. Sections
are visual cards over dark elevated surfaces. Each setting card carries a
label and an accessory; a description/value is shown when the architecture
provides one.

## Destination and scope

In the current navigation model the Settings surface is the `.settings`
destination, which also presents the Providers surface (DES-012 §3.5): the
`Providers` and `Settings` items of the navigation drawer both route here. The
Settings screen therefore presents the providers content and the representable
settings items in one surface, on the same tokens.

Not representable by the current architecture — do not invent:

- `Default provider`: provider selection is per-conversation context composed
  by the shell (UX audit V2); it is not a settings value, and no
  `Default provider` row is fabricated.
- A persisted theme: the Dark Mode value is presentation-only shell state
  shared with the navigation drawer's Dark Mode card; it is never persisted.

## Top bar

- hamburger/menu button on the leading side (inert — navigation is owned by the
  shell)
- centered title: `Providers` (new_design.md §7)
- add-connection `+` button on the trailing side

## Sections

Order:

1. **Provider** — the prominent Active Provider card and the All Providers
   rows, or the empty state. Each connection: provider glyph, display name,
   lifecycle label, status indicator, overflow menu (new_design.md §7).
2. **Configuration** — the typed configuration values as label/value cards.
3. **Appearance** — one card row: moon icon, `Dark Mode` label, toggle
   accessory. The toggle drives the shell's preferred color scheme
   (presentation-only, shared with the drawer's Dark Mode card).
4. **About** — one card row: info icon, `About` label, chevron accessory.
   Routes to the About screen.
5. Security hint — the lock icon caption stating the providers are stored
   securely on this device.

## Card geometry

- `OmniaCard` surfaces: `elevatedSurface`, card corner radius, subtle border.
- Setting rows: leading SF Symbol (secondary text tone, 22pt slot), body label
  (primary text tone), spacer, accessory (toggle / chevron).
- Section headers via `SectionHeader`.

## Implementation guidance

Reuse `OmniaTheme` tokens, `OmniaCard`, `SectionHeader`, the existing
localization catalog, and SF Symbols (`moon`, `info.circle`,
`chevron.right`). Keep business/network logic outside the view; the view
renders state and translates intent callbacks.
