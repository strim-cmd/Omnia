# UI Redesign Plan

Task: `Documentation/Design/new_design.md` — a systematic redesign of the Omnia Presentation layer to a single premium "private AI assistant" design system (dark futuristic + minimal + premium + clean), with a real light theme, semantic design tokens, a compact capsule composer, card-based lists, a provider pill selector, a side menu, and premium empty/error/streaming states.

## Frozen Boundaries (must NOT change)

- Domain, Application, Infrastructure layers, and their public contracts.
- Frozen presentation value types and their public APIs (`ConversationScreenState`, `ConversationListState`, `SettingsState`, `ConversationListItem`, `MessagePresentation`, `MarkdownContent`, `NavigationState`, `NavigationSurface`, the three surfaces).
- Public view initializers used by the shells (`RootView`, `ConversationListView`, `ConversationScreenView`, `SettingsView`, the form/editor views, `MarkdownView`). Internal bodies may be rewritten; signatures are kept stable. Any small addition (e.g. a `onOpenMenu` callback) is additive and wired only in `RootView`.
- Navigation model (`NavigationState.Route`: conversation list / conversation screen / settings). The side menu routes through the same frozen routes; it adds no route.
- OmniRoute integration, provider API contracts, message streaming behavior, conversation behavior.
- All behavior preserved: send/cancel/retry, provider selection persistence, streaming announcements, near-bottom auto-scroll, delete/remove confirmation dialogs, Dynamic Type, VoiceOver, keyboard behavior, localization keys (only additive).

## Constraints Discovered

1. The Domain `Conversation` aggregate (DES-009 §3.3) carries **no timestamp**, so the "Today / Yesterday / Previous 7 Days" grouping of the concept (§6) cannot be derived from frozen data. The list renders a flat, card-based set of rows instead (design language preserved; grouping documented as a limitation).
2. There is no "Providers" or "About" route in the frozen navigation model, so the side menu maps "Providers" to the settings surface (where provider connections live) and "About" to an about alert. No route is added.
3. The pushed conversation screen keeps the system navigation bar (restyled) so back navigation / interactive pop is never lost — no navigation regression.
4. No Swift toolchain is available in this environment (Windows). SwiftUI code is Apple-platform (`#if canImport(SwiftUI)`) and cannot be compiled here; the Linux/CI test suite covers only the value types, which are untouched by this redesign. Verification happens through careful review here and on-device by the user (per the task's workflow).

## Existing Assets (reused, extended — no duplicates)

- `OmniaTheme` in `DesignTokens.swift` — extended to a full semantic, adaptive (dark + light) token system instead of a second system.
- `MessageBubbleView` — restyled with the new tokens; gains compact message actions.
- `EmptyStateView` — restyled premium (Omnia mark + glow).
- `ErrorBannerView` — restyled premium (dark-red tinted card) with a variant for warnings.
- `Localized` catalog — extended with new keys (additive only).

## New Components (single file each, package conventions)

| Component | Purpose |
| --- | --- |
| `OmniaBackground` | Root gradient background (subtle navy undertone). |
| `OmniaCard` | Reusable elevated card: `elevatedSurface`, subtle border, soft shadow, rounded 16–20. |
| `OmniaPill` | Compact elevated capsule container + status dot. |
| `OmniaButton` | Accent primary button (filled, white text) + secondary/bordered variant. |
| `OmniaIconButton` | Thin circular icon button (attachment, send, stop, menu, etc.). |
| `StatusIndicator` | Green dot + lifecycle label for provider connection states. |
| `SectionHeader` | Muted section title with the typography scale. |
| `ComposerView` | The capsule composer (attachment + expanding field + round send/stop). |
| `SideMenuView` | The navigation drawer overlay (spec §8). |
| `ProviderPillView` | The compact provider selector pill (spec §5). |

## Work Plan (blocks, each followed by review + test where runnable)

1. **Tokens**: adaptive semantic `OmniaTheme` (dark + light palettes, radii scale, spacing scale, typography, shadows). Update `MarkdownView` code-block surface to tokens.
2. **Components**: `OmniaBackground`, `OmniaCard`, `OmniaPill`, `OmniaButton`, `OmniaIconButton`, `StatusIndicator`, `SectionHeader`.
3. **Conversation screen**: `ComposerView` (~50–60 pt single line, expands 1–6 lines, scrolls after), provider pill selector, premium bubbles (user right purple / assistant left elevated, max width, compact actions), streaming "Thinking/Streaming" indicator, restyled navigation bar, jump-to-latest restyle.
4. **Conversation list**: custom light top bar (menu, "Conversations", new chat), search capsule, card rows with icon/title/preview/chevron, confirmation dialog kept.
5. **Navigation shell**: `SideMenuView` drawer in `RootView` (New Chat, Conversations, Providers→Settings, Settings, About, dark-mode toggle), `preferredColorScheme` from persisted appearance.
6. **Settings**: card-based sections (Provider Connections, Appearance, About) replacing `Form` appearance; connection cards with icon/name/endpoint/status/overflow; form and editor views restyled with tokens.
7. **States**: premium empty state (Omnia mark + soft glow), error card (dark red tinted, retry), warning banner.
8. **Localization**: add keys (composer placeholder, search placeholder, thinking/streaming, empty state, error card, appearance/about, side menu, message actions), keep existing keys unchanged.
9. **Final**: full review against acceptance criteria, full test suite (run on macOS/CI), write `UI_REDESIGN_FINAL.md`. No commit, no push, no merge.

## Acceptance Mapping (spec §21)

1–4. Conversation screen premium style, compact composer 50–60 pt, expanding, bubble hierarchy.
5. Provider selector compact pill. 6–8. Card-based list / providers / settings.
9–10. Cohesive dark theme, real light theme (not inversion). 11–12. Semantic tokens, no hardcoded colors/spacing.
13. Consistent SF Symbols. 14–15. UX contracts and OmniRoute preserved.
16. Existing tests pass. 17–20. No build errors, no navigation/localization/accessibility regressions.
