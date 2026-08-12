# Omnia UI — Settings Screen

## Reference

Implement the Settings screen in the same design language as the rest of the
interface (new_design.md §9): never the standard iOS Form appearance. Sections
are visual cards over dark elevated surfaces. Each setting card carries a
label and an accessory; a description/value is shown when the architecture
provides one.

## Destination and scope

The Settings surface is the `.settings` destination of the navigation
structure (DES-012 §3.5): application settings only. Provider-connection
management is a distinct destination — the `.providers` route (new_design.md
§7) — rendered by `ProvidersView`; the `Providers` and `Settings` items of the
navigation drawer route to their own surfaces.

Not representable by the current architecture — do not invent:

- `Default provider`: provider selection is per-conversation context composed
  by the shell (UX audit V2); it is not a settings value, and no
  `Default provider` row is fabricated.

## Top bar

- hamburger/menu button on the leading side (inert — navigation is owned by the
  shell)
- centered title: `Settings`
- trailing spacer keeping the title centered

## Sections

Order:

1. **Configuration** — the typed configuration values as label/value cards
   (new_design.md §13), or the empty state.
2. **Appearance** — one card row: moon icon, `Dark Mode` label, toggle
   accessory. The toggle drives the shell's preferred color scheme through the
   shared drawer/settings binding, persisted at the user-owned workspace level
   and restored on launch.
3. **About** — one card row: info icon, `About` label, chevron accessory.
   Routes to the About screen.

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
