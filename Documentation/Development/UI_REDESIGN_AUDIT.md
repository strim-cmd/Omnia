# Omnia UI Redesign — Read-Only Audit Report (Fresh Pass)

- Date: 2026-08-11 (second pass; A1–A4 from the first pass are now implemented and verified)
- Scope: `Packages/OmniaPresentation` (SwiftUI) vs. `Documentation/Design/new_design.md` (§1–§22) + `Documentation/UI/*`
- Mode: read-only audit — **no files changed, no commits, no pushes**. All findings below were re-verified by direct file reads this pass (the shell grep layer has been intermittently corrupted; reads are authoritative).

## 1. Verification of the Previous Pass's Action Items (A1–A4)

| Item | Verdict | Evidence |
|---|---|---|
| A1 — assistant bubbles render Markdown | **VERIFIED** | `ConversationScreenView.swift:561` `MarkdownView(content: content)`; `MessagePresentation.content` is `MarkdownContent?` (`MessagePresentation.swift:19`) and `MarkdownView` takes it directly. Bubble chrome preserved: `surface` fill, `border` stroke 0.5, `Shadows.bubble`, `maxBubbleWidth`, `Radii.bubble`; `Typography.body == Font.body` (`DesignTokens.swift:191`), so no typography regression. User bubble stays plain `Text` on the purple gradient (`:536`). |
| A2 — copy routes through `onCopy` | **VERIFIED** | `ConversationScreenView.swift:476` `action: { onCopy(index) }`; the dead local pasteboard helper is gone. `RootView.swift:576` `copy(at:)` guards `indices.contains` — an invalid index (incl. `-1`) is a no-op, never a crash. `RootView.swift:247` wires `onCopy: copy(at:)`. |
| A3 — missing localization keys added | **VERIFIED** | `Localizable.strings:42` `initializing`, `:82` `remove_provider_connection`, `:83` `remove_provider_connection_confirmation`, `:84` `removed`; referenced by `Localized.swift:48/90-92`, used by `StatusIndicator` (`:42`, `:46`). Full catalog now matches `Localized.swift` — no key is referenced but missing. |
| A4 — hardcoded `.red` validation | **VERIFIED** | `ProviderConnectionFormView.swift:331` `validationMessage` uses `OmniaTheme.Colors.error`. |

## 2. PASS — Screens Verified Against the Reference

**Conversation screen (§5) — `ConversationScreenView.swift` (936 ln)**
- Top bar `[hamburger][title][compose]`, light, 36 pt glyphs, 52–60 pt band (`:174-190`). Menu/compose are inert by design — shell-owned navigation, documented in-code and CHAT.md.
- Provider selector: compact capsule pill `Menu` — green status dot (amber when the explicit selection is unavailable), name or `Automatic`, chevron, elevated+stroke+shadow, centered below the top bar, loading/empty/error states (`:288-423`). Matches §5.
- Thinking/streaming: elevated `stateCard` with sparkles, title/subtitle, subtle animated waveform (`:648-727`); interrupted shows partial content + Retry (`:698-710`). Matches §12.
- Error state: `errorSubtle` fill, `error` border + icon, `textPrimary`/`textSecondary` copy, Retry (`:789-819`). Matches §11 ("not screaming red, dark red tinted surface").
- Composer: single capsule control `[paperclip inert][vertical field minHeight 50 / maxHeight 150][round send arrow.up accent / stop while streaming]`, placeholder "Message Omnia...", muted, keyboard-safe (`:195-246`). Matches §5/§21.
- User bubble: trailing purple gradient, white text, rounded, max reasonable width (`:533-554`). Assistant bubble: leading elevated card + action row (`:558-576`).
- Empty state (sparkles + glow), Today marker, auto-scroll + jump-to-latest, VoiceOver streaming announcements (`:429-448`, `:740-777`, `:821-844`). Matches §10/§5.

**Conversation list (§6) — `ConversationListView.swift` (319 ln)**
- Header `[hamburger→drawer][Conversations][new-chat→create]` (`:100-115`); search capsule, functional client-side filter + clear (`:119-148`); plain `List` with hidden separators, card rows `[accentSubtle bubble tile][title|preview|chevron]` (`:167-265`); swipe + context-menu delete with explicit confirm dialog (U5); `EmptyStateView` for empty. System nav bar hidden (`:73-77`).
- Single "Today" group only — no row timestamps exist in the data model; documented compromise.

**Providers + Settings (§7/§9) — `SettingsView.swift` (548 ln)**
- Top bar `[hamburger inert][Providers][+ add]` (`:175-191`). Active-Provider card (accent `network` glyph, name, lifecycle label, green Active pill) `:306-350`; All-Providers rows (status dot, name, label, ellipsis menu: Edit Endpoint / Edit Model / Remove) `:355-402`; configuration key-value cards; Appearance → Dark Mode row (shared, never persisted — follows SETTINGS.md); About row → About; security hint; compose/endpoint/model editors with pre-filled input; remove `confirmationDialog` (`:150-167`). Empty-connections card with working Add Connection.

**Side menu (§8) — `SideMenuView.swift` (265 ln)**
- Brand `[O monogram][Omnia][workspace]`; rows New Chat / Conversations / Providers (count badge) / Settings / About; selected row = `accentSubtle` fill + accent icon + semibold + `.isSelected` (matches §8 "subtle purple background, rounded 12–14"); bottom compact Dark Mode card. NOTE: the first-pass "purple left border" item (A9) is **not** supported by §8 — the reference asks for a subtle purple background; the implementation matches the reference.

**About (§14/§20) — `AboutView.swift` (103 ln)**
- Brand block `[O][Omnia][workspace]` only; no version/build — explicitly documented because the application state carries none (honest rendering). Reached from the drawer; system back is the back behavior.

**Design system**
- All screens use `OmniaTheme` tokens (adaptive semantic colors, Dynamic Type typography, spacing/radii/shadows). `EmptyStateView`, `StatusIndicator`, `OmniaCard`, `OmniaButton`, `OmniaIconButton`, `SectionHeader`, `OmniaBackground` are token-based. No hardcoded semantic colors remain in screens (only the shared banner, below). Icons are thin SF Symbols at 28–40 pt glyphs / 18–22 pt content (matches §15 convention).

## 3. UI-ONLY FINDINGS (actionable, no architecture change)

### P0 — ErrorBannerView hardcodes harsh red on 3 surfaces
`ErrorBannerView.swift:13` `backgroundColor: Color = .red`; `:36` `.background(backgroundColor.opacity(0.8))`; `:20` `Color.white` text; `:40` white stroke; `:29` white retry pill.
Violates §11 ("Ошибка не должна быть screaming red — dark red tinted surface") and the no-hardcoded-color rule. Used by the list failure banner (`ConversationListView.swift:299`), the conversation provider-load failure (`ConversationScreenView.swift:781`), and the settings failure banner (`SettingsView.swift:501`) — so 3 screens show it, inconsistent with the error-token treatment of the inline `errorState`.
**Fix (UI-only, ~6 lines):** default `backgroundColor` to `OmniaTheme.Colors.errorSubtle`, icon/`foregroundStyle` to `textPrimary`+`error`, stroke to `error.opacity(0.3)`, retry pill to an error-tinted capsule — mirroring `ConversationScreenView.swift:789-819`.

### P1 — Action row renders on partial/streaming content
`streamingBubble` (`ConversationScreenView.swift:604-624`) renders `assistantBubble(..., index: -1)` for `.active(partialContent)` and `.interrupted(partialContent)`; `assistantBubble` always emits `assistantActionRow` for an `.assistant` role (`:572-573`). Copy/like/dislike/regenerate therefore appear on the growing/incomplete bubble with `index: -1` — all inert via the `RootView` index guards, but visually wrong vs. §5 (actions "появляются unobtrusively" under completed messages).
**Fix (UI-only):** render the streaming/interrupted partial content without the action row (only the bubble). Like/dislike local sets would also stop receiving `-1` entries.

### P1 — Duplicate navigation bar on pushed screens (needs on-device verification)
`ConversationListView` hides the system bar (`:73-77`), but the three pushed screens do not: `ConversationScreenView.swift:157-158` sets `.toolbarBackground(.visible, for: .navigationBar)`; `RootView.swift:250` sets `.navigationTitle(...)` on the conversation screen; `RootView.swift:134-141` adds a `gearshape` `ToolbarItem(.primaryAction)` that also appears on pushed screens. Result on device (high confidence from source): each pushed screen renders the **system** nav bar `[back][title][gear]` **above** its custom top bar `[hamburger][title][compose/+]` — duplicated chrome/title. Back-button tint also diverges (`ConversationScreenView.swift:160` `.tint(accent)` → purple back on conversation; settings/about have no `.tint` → default blue).
Cannot be confirmed by compilation on this host (no toolchain) — **verify on device**, then resolve. This touches back-button ownership, so it is a chrome/navigation decision (see Blockers).

### P2 — Dead components + orphaned localization keys
Unused in sources (only self-references + tests): `MessageBubbleView`, `ComposerView`, `OmniaPill`, `BubbleTextColor`. `MarkdownView` is now live (A1). Their orphaned keys (`assistant_message`, `message_actions`, `user_message`, `back`, `preparing`, `no_conversations`, `no_conversations_description`, `provider_connections`, `remove_provider_confirmation`, `retry_interrupted_response`) can be pruned only if the components are deleted. Deleting is UI-only and test-verifiable, but touches `Localized.swift`/strings — do as its own change.

### P2 — Providers-count badge accessibility
`SideMenuView.swift:201` `Text("\(count)")` — announced as part of the combined row label; an explicit `accessibilityValue` would be clearer. Trivial.

## 4. BLOCKERS / OUT OF SCOPE THIS PASS (do not touch — architecture or data model)

- **Timestamps + delivery check marks** (§5 bubbles, §6 date groups): the data model carries no timestamps. The Today marker and single Today group are the documented honest compromise. Do not invent timestamps.
- **Version footer (drawer) and version/build (About)** (§8/§20): the application state carries no version; `MARKETING_VERSION` lives only in `App/Config/Shared.xcconfig` and is not plumbed into the presentation contract. Surfacing it is a contract change.
- **Dark Mode persistence** (§13 vs. SETTINGS.md): §13 implies persistence; implementation and SETTINGS.md say never persisted. Needs a contract decision.
- **Inert "Open Settings" buttons** in the empty/unavailable provider banners (`ConversationScreenView.swift:325-329`, `:414-418`): wiring requires a cross-surface navigation callback (shell change).
- **Inert top-bar menu/compose affordances** (conversation, settings, about): documented shell-owned navigation.
- **Double navigation bar resolution** (P1 above): requires choosing chrome ownership (hide system bar + custom back, or keep system bar and drop custom bars) — a navigation decision.

## 5. Priorities & Implementation Order

1. **P0** — `ErrorBannerView` token fix (errorSubtle/error, not `.red`/white). ~6 lines, 3 surfaces fixed.
2. **P1** — suppress the action row on streaming/interrupted partial content.
3. **P1 (decide + verify)** — unify navigation chrome on pushed screens (on-device confirm first).
4. **P2** — delete dead components + prune orphaned keys (own commit).
5. **P2** — providers-badge `accessibilityValue`.

## 6. Commit Recommendation (decision for the user; nothing committed this pass)

The working tree holds verified, self-contained work (A1–A4 fixes, new `AboutView`, `Documentation/UI/*`, this report) — 13 modified + 3 untracked files, HEAD `574328f`, nothing pushed. Recommended sequence:
1. Verify on the physical iPhone first (per §22; toolchain unavailable here).
2. Apply the two trivial UI-only fixes (P0 banner, P1 streaming actions) — or after verification.
3. Then one commit for the A1–A4 group, and a second for the remaining UI-only fixes + dead-code removal. Commit-now-vs-later is the user's call; §22 and this audit's read-only mode argue for keeping the tree uncommitted until the user's device check.

## 7. Final Compliance

- Files changed this pass: **0** (audit strictly read-only).
- Commits/pushes: **0**.
- Verification: source inspection only (`swift` unavailable on Windows); every finding re-confirmed by direct reads; the shell grep layer was not trusted for evidence.
