---
title: OmniRoute Integration — Step 3 Report (presentation: model field, Edit Model, threading)
document_id: OMNIROUTE-INTEGRATION-STEP3
version: 0.1.0
status: Implemented — Linux suite green; not committed, not pushed
created: 2026-08-09
project: Omnia
related_documents:
  - Documentation/Development/OMNIROUTE_INTEGRATION_PLAN.md
  - Documentation/Development/OMNIROUTE_INTEGRATION_STEP1.md
  - Documentation/Development/OMNIROUTE_INTEGRATION_STEP2.md
  - Documentation/Design/APPLICATION_API.md
  - Documentation/Design/PRESENTATION_API.md
  - Packages/OmniaPresentation/Sources/OmniaPresentation/ProviderConnectionFormView.swift
  - Packages/OmniaPresentation/Sources/OmniaPresentation/ProviderModelEditorView.swift
  - Packages/OmniaPresentation/Sources/OmniaPresentation/SettingsView.swift
  - Packages/OmniaPresentation/Sources/OmniaPresentation/RootView.swift
  - Packages/OmniaPresentation/Sources/OmniaPresentation/SettingsSurface.swift
  - Packages/OmniaPresentation/Sources/OmniaPresentation/SettingsState.swift
---

# OmniRoute Integration — Step 3: presentation surface (model field, Edit Model, threading)

## Summary

Step 3 completes the OmniRoute integration from the UI. The connection form now
collects an optional generic **Model** field; the settings connection rows now
offer an **Edit Model** affordance beside **Edit Endpoint**; `RootView` threads
the model through `configure(_:endpoint:model:)` and the new
`updateModel(_:for:)`/`model(for:)` surface methods; and the new user-visible
strings are localized. A user can now record a per-provider model name (the
OmniRoute combo, or any OpenAI-compatible provider model name) from the UI,
closing the loop started in step 1 (storage) and step 2 (selection and routing).

The SwiftUI view layer (`ProviderConnectionFormView`, the new
`ProviderModelEditorView`, `SettingsView`, `RootView`) is Apple-platform code
isolated behind `canImport(SwiftUI)` and is not exercised by the Linux test
environment; it is verified by review per DES-012 §3.7. The testable seam — the
additive `SettingsSurface` model surface and the new `SettingsState.ModelEditing`
condition — is covered by the Linux suite. Nothing was committed or pushed.

## Changes

### 1. `ProviderConnectionFormView` — optional Model field (DES-012 §3.4)

`Packages/OmniaPresentation/Sources/OmniaPresentation/ProviderConnectionFormView.swift`

- Added an optional `@State model` text field in the Connection section, next to
  the Endpoint field (autocorrection disabled, no autocapitalization, URL
  keyboard on iOS).
- Extended `onConfigure` from a `(ConfigureProviderRequest, String)` pair to the
  `(ConfigureProviderRequest, String, String)` triple — request, endpoint, model —
  and `submit()` now passes the trimmed model.
- An empty model is allowed and records no model, so the provider falls back to
  the app-edge default (`configure(_:endpoint:model:)` takes `String?`); the
  model is not part of the `canSubmit` gate.

### 2. `ProviderModelEditorView` — new view (DES-012 §3.4)

`Packages/OmniaPresentation/Sources/OmniaPresentation/ProviderModelEditorView.swift` (new)

- A sibling of `ProviderEndpointEditorView`: pre-filled with the connection's
  currently recorded model, a footer explaining what the model is, Save
  disabled while empty (the service rejects an empty model with the typed
  `ApplicationValidationError`), Cancel and Save toolbar actions, and an
  accessibility label on Save. The interface is generic and never changes per
  provider (PRODUCT_PRINCIPLES — Provider Independence).

### 3. `SettingsView` — Edit Model intents (DES-012 §3.4)

`Packages/OmniaPresentation/Sources/OmniaPresentation/SettingsView.swift`

- New intent closures mirroring the endpoint-edit pattern: `onEditModel:
  (ProviderConnectionListItem) -> Void`, `onUpdateModel:
  (ProviderIdentity, String) -> Void`, and `onCancelModelEdit: () -> Void`.
- The connection row's context menu gains an **Edit Model** action beside
  **Edit Endpoint**.
- When `state.editingModel` holds, the model editor is presented, exactly as the
  endpoint editor is presented when `state.editing` holds.
- `onConfigure` type updated to the triple.

### 4. `RootView` — threading (DES-012 §3.4)

`Packages/OmniaPresentation/Sources/OmniaPresentation/RootView.swift`

- `settingsScreen` now passes `onEditModel`, `onUpdateModel`, and
  `onCancelModelEdit` to `SettingsView`.
- `configure(_:endpoint:model:)` hands the triple to
  `surface.settings.configure(_:endpoint:model:)`, mapping an empty/whitespace
  model to `nil` so no model is recorded.
- New `editModel(_:)` resolves the recorded model through
  `surface.settings.model(for:)` and presents the model-edit condition;
  `updateModel(_:_:)` records through `surface.settings.updateModel(_:for:)` and
  reloads; `cancelModelEdit()` clears the condition.
- `failingSettingsState(_:)` preserves the model-edit condition, so a failed
  model update keeps the editor presented with its input retained (ARC-001),
  matching the endpoint editor.

### 5. `SettingsSurface` — additive model surface (DES-012 §3.4)

`Packages/OmniaPresentation/Sources/OmniaPresentation/SettingsSurface.swift`

- `configure(_:endpoint:model:)` — additive overload that configures the
  connection and records the endpoint and, when given, the model through the
  already-frozen `ProviderConnectionService.configure(_:endpoint:model:)` of
  step 1 (DES-011 §3.9).
- `updateModel(_:for:)` and `model(for:)` — thin delegations to the frozen
  `ProviderConnectionService` model surface.
- These are additive members of the Presentation seam; no Application, Domain,
  Infrastructure, or App contract changed in this step.

### 6. `SettingsState` — model-edit condition (DES-012 §3.2)

`Packages/OmniaPresentation/Sources/OmniaPresentation/SettingsState.swift`

- New `ModelEditing` value type (identity, display name, current model),
  mirroring the endpoint `Editing` type; a provider with no recorded model
  presents `currentModel == ""`.
- New `editingModel: ModelEditing?` property and a defaulted `editingModel`
  initializer parameter, so all existing constructions compile unchanged.

### 7. Localization

`Packages/OmniaPresentation/Sources/OmniaPresentation/Localized.swift` and
`Packages/OmniaPresentation/Sources/OmniaPresentation/Resources/en.lproj/Localizable.strings`

- New keys (added alphabetically): `model` ("Model"), `edit_model` ("Edit
  Model"), `save_model` ("Save Model"), and `update_model` ("Update the model %@
  uses.") with a `Localized.updateModel(_:)` format helper mirroring
  `updateEndpoint(_:)`. The new strings follow UI.md §Localization; the
  pre-existing unlocalized form strings are untouched.

## Deviations from the plan (flagged for review)

The plan's step-3 sketch noted "no change to `SettingsSurface`, `SettingsState`",
but the plan's own §8 mandates two of the changes: "extend `onConfigure` to a
`(ConfigureProviderRequest, String, String)` triple … and `SettingsSurface.configure`
accordingly". So the `SettingsSurface.configure(_:endpoint:model:)` addition is
**required by the plan, not a deviation from it**. The genuine additions beyond
the plan are:

- `SettingsState` to carry a `ModelEditing` condition — the plan did not mention
  it, but it is required by the plan's own step 3.2/3.4 ("Edit Model" in
  SettingsView, pre-filled editor, Save via `configure(_:endpoint:model:)`): the
  model editor cannot be pre-filled with the recorded model or kept open with
  its input retained on a failed update without a model-edit condition, both of
  which are the endpoint editor's established behavior (ARC-001, UX audit U7
  pattern). `editingModel` has a `nil` default, so the `SettingsState` init is
  backward-compatible.
- The `ProviderConnectionFormView.onConfigure` and `SettingsView.init` signature
  changes — the plan mandated the `onConfigure` triple (a modification, not an
  addition: the two-arg closure was not retained), and `SettingsView.init` gained
  three required parameters (`onEditModel`, `onUpdateModel`, `onCancelModelEdit`;
  no overload retained). Both are confined to the SwiftUI view layer, the only
  consumer is `RootView`, and the DES-012 §3.2/§3.4 revision (this change)
  authorizes them explicitly per DES-012 §6.3.
- `SettingsSurface` to expose the additive model surface — otherwise `RootView`
  has no seam to call `configure(_:endpoint:model:)` or `updateModel`, and the
  plan explicitly forbids reaching the Application service directly from the
  shell's intent handlers (ARC-006). The new members delegate straight to the
  frozen Application surface from step 1.

The model surface, model-edit condition, and the threading intents are additive
Presentation-layer (DES-012) changes; the two view-layer signature changes are
modifications authorized by the DES-012 revision. No frozen
Application/Domain/Infrastructure contract changed. This is a deliberate
interpretation of the plan; it is called out here for review.

## Tests

### `SettingsSurfaceTests` (+9 tests, Linux)

- `testConfigureWithEndpointAndModel_RecordsTheModelAtProviderSettingsLevel` —
  `configure(_:endpoint:model:)` records the model under
  `ProviderConnectionService.modelKey(for:)` at `.providerSettings`.
- `testConfigureWithEndpointAndModel_NilModelRecordsNoModel` — `nil` records
  nothing, so the provider falls back to the app-edge default.
- `testConfigureWithEndpointAndModel_WhitespaceModelSurfacesAsApplicationValidationError`
  — a whitespace model is rejected before any write; nothing is configured.
- `testModel_ReturnsNilWhenNoModelIsRecorded`.
- `testUpdateModel_RecordsTheModelAtProviderSettingsLevel`,
  `testUpdateModel_TrimsWhitespaceAroundTheModel`,
  `testUpdateModel_ReplacesThePreviouslyRecordedModel`.
- `testUpdateModel_EmptyModelSurfacesAsApplicationValidationError` — the
  previous model is preserved on rejection.
- `testUpdateModel_RepositoryFailureSurfacesAsRepositoryError` — failures
  surface as-is, never wrapped.

### `SettingsStateTests` (+5 tests, Linux)

- `testCreation_EditingModelDefaultsToNil`,
  `testModelEditCondition_ReflectsTheModelEditFlow`,
  `testModelEditCondition_CurrentModelDefaultsToEmptyWhenNoneIsRecorded`,
  `testEquality_DifferentModelEditConditionIsNotEqual`,
  `testEquality_ModelEditingEqualToItself`.

## Test Results (Linux suite, swift:6.0, `the Linux CI container`)

| Package | Executed | Failures |
|---|---|---|
| OmniaFoundation | 136 | 0 |
| OmniaDomain | 318 | 0 |
| OmniaApplication | 177 | 0 |
| OmniaInfrastructure | 187 | 0 |
| OmniaPresentation | 199 (+14 new) | 0 |
| OmniaApp | 39 | 0 |
| root skeleton | 1 | 0 |

`swift build` on the modified package: no warnings.

## Architecture Checks

- **ARC-001** — a failed model update keeps the model editor presented with its
  input retained; the failures the service surfaces (`ApplicationValidationError`,
  `RepositoryError`) are presented as-is, never wrapped.
- **ARC-002 / ARC-004** — no business rule moved; the model is connection
  configuration that never enters the `ConfigureProviderRequest` or any Domain
  aggregate, exactly like the endpoint.
- **ARC-005** — the model is non-secret connection configuration, stored as a
  typed configuration value at the provider-settings level; the credential stays
  by reference and untouched.
- **ARC-006 / ARC-009** — composition is unchanged; the settings surface remains
  the only seam the shell uses to reach the Application service.
- **Frozen contracts** — Domain (DES-009), Infrastructure (DES-010), and App
  (DES-013) untouched in this step; Application (DES-011) untouched in this
  step (its model surface is consumed, not redefined — it was already added
  additively in step 1). Presentation (DES-012) gains additive members plus two
  authorized view-layer signature modifications — `ProviderConnectionFormView.onConfigure`
  extended to the `(ConfigureProviderRequest, String, String)` triple and
  `SettingsView.init` gaining `onEditModel`/`onUpdateModel`/`onCancelModelEdit` —
  both mandated by the plan's §8 and authorized by the DES-012 §3.2/§3.4
  revision. Spec revisions are addressed in this same change (DES-011 §3.4/§3.9/§3.10,
  DES-012 §3.2/§3.4, DES-013 §3.3).

## Architectural Risks

- **SwiftUI is review-only**: the four SwiftUI files are not compiled on Linux
  (DES-012 §3.7). They were written to mirror the existing, reviewed
  `ProviderEndpointEditorView` and endpoint-edit threading exactly; the behavior
  they drive is covered at the surface/state seam by the Linux tests.
- **Labeling is generic, not OmniRoute-specific**: the field is labeled "Model",
  not "Model / Combo" (the plan listed both as candidates), honoring Provider
  Independence for every OpenAI-compatible gateway.
- **Legacy form strings remain unlocalized**: the pre-existing hard-coded
  strings in `ProviderConnectionFormView`/`ProviderEndpointEditorView` were left
  unchanged (out of scope); only the new strings use `Localized`. Migrating the
  legacy strings is a possible follow-up.
- **Spec revisions**: DES-011 §3.4/§3.9/§3.10, DES-012 §3.2/§3.4, and DES-013
  §3.3 are revised in this same change per the frozen-contract change process;
  the view-layer signature modifications are authorized explicitly (DES-012 §6.3).

## Acceptance Criteria

1. The connection form collects an optional model; an empty model records no
   model, so the provider falls back to the app-edge default model.
2. Saving a connection records the model through
   `configure(_:endpoint:model:)` — `ProviderConnectionFormView` →
   `SettingsView`/`RootView` → `SettingsSurface` → the frozen
   `ProviderConnectionService` — with the credential entering only the frozen
   `ConfigureProviderRequest` (ARC-001, ARC-005).
3. Settings rows offer **Edit Model** beside **Edit Endpoint**; the model editor
   is pre-filled with the recorded model, an empty model is rejected with the
   typed `ApplicationValidationError`, and a failed update keeps the editor open
   with its input retained (ARC-001).
4. `RootView` threads `onEditModel`/`onUpdateModel`/`onCancelModelEdit` and
   saves through `surface.settings.updateModel(_:for:)` and
   `configure(_:endpoint:model:)`.
5. The new user-visible strings exist in both `Localized.swift` and
   `Localizable.strings` and follow UI.md §Localization.
6. The Linux suite stays green (0 failures, 0 new warnings); the SwiftUI
   additions are review-only per DES-012 §3.7.
7. No Application, Domain, or Infrastructure contract changed in this step.
8. Nothing committed, pushed, or merged.

## What Remains

1. **Spec revisions (done in this change):** the additive model surface of
   DES-011 §3.4/§3.9/§3.10, the DES-012 §3.2/§3.4 form/editor intents with the
   authorized view-layer signature changes, and the DES-013 §3.3 config-driven
   `preferredModels` are revised in the same change as the code, per the
   frozen-contract change process.
2. **Review of the SwiftUI layer** against `project UI standards` on an Apple
   platform (the new `ProviderModelEditorView`, the Model field, the Edit Model
   context-menu action, and the RootView threading).
3. **Follow-up (Option B):** live model listing via `GET {endpoint}/models` as a
   best-effort picker, kept optional behind manual entry.
4. **Follow-up:** migrate the legacy hard-coded form/editor strings to
   `Localized`.
