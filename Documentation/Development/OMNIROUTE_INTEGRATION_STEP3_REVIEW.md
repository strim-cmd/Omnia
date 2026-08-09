---
title: OmniRoute Integration — Step 3 Review
document_id: OMNIROUTE-INTEGRATION-STEP3-REVIEW
version: 0.1.0
status: PASS WITH CHANGES
created: 2026-08-09
project: Omnia
reviewer: Chief Architect (review pass)
related_documents:
  - Documentation/Development/OMNIROUTE_INTEGRATION_PLAN.md
  - Documentation/Development/OMNIROUTE_INTEGRATION_STEP1.md
  - Documentation/Development/OMNIROUTE_INTEGRATION_STEP2.md
  - Documentation/Development/OMNIROUTE_INTEGRATION_STEP3.md
  - Documentation/Design/APPLICATION_API.md
  - Documentation/Design/PRESENTATION_API.md
  - Documentation/Design/DOMAIN_API.md
  - Documentation/Design/INFRASTRUCTURE_API.md
  - Documentation/Design/APP_API.md
  - .ai/standards/UI.md
---

# OmniRoute Integration — Step 3 Review

> **Closure note.** All findings of this review are closed in the current tree:
> B1/B2 and N2 were resolved by the spec revisions (DES-011 v1.2.0 §3.10,
> DES-012 v1.2.0, DES-013 v1.1.0) that shipped with the code; R1–R3 by the report
> corrections; and the remaining non-blocking items — N1 (the plan §9 Domain
> selection test, added as
> `ProviderSelectionServiceTests.testSelect_SelectsTheRecordedComboWhenItIsTheOnlyOfferedModel`)
> and the stale `DES-011 §3.9` doc-comment references (FINAL_REVIEW N3) — by the
> follow-up revision. See `OMNIROUTE_INTEGRATION_FINAL_REVIEW.md` (PASS) for the
> final verdict. This document is preserved unchanged as the record of the
> review pass.

## Scope and Method

Read-only review of the OmniRoute integration working tree (Steps 1–3, none of
it committed). No code was changed during the review.

Reviewed: the plan; the STEP1/STEP2/STEP3 reports; the frozen spec documents
DES-011 (APPLICATION_API.md), DES-012 (PRESENTATION_API.md), DES-009
(DOMAIN_API.md), DES-010 (INFRASTRUCTURE_API.md), DES-013 (APP_API.md); the
Application layer (`ProviderConnectionService`), the App layer
(`CompositionRoot`, `ProviderAdapterBinding`, `AppEdgeConstants`, `OmniaAppTests`),
the Presentation layer (`SettingsState`, `SettingsSurface`,
`ProviderConnectionFormView`, `ProviderModelEditorView`, `SettingsView`,
`RootView`, `Localized`, `Localizable.strings`), and the test files
(`SettingsStateTests`, `SettingsSurfaceTests`, `ProviderConnectionServiceTests`,
`OmniaAppTests`). The SwiftUI view layer was reviewed from source against DES-012
§3.7; it is not compiled on Linux by design.

Re-verified against the current tree: `swift test` for OmniaPresentation — **199
executed, 0 failures**. The full-suite counts from STEP1/STEP2/STEP3 (Foundation
136, Domain 318, Application 177, Infrastructure 187, Presentation 199, App 39,
root 1) match the last recorded full run on this same tree.

## Verdict

# PASS WITH CHANGES

The implementation is correct, well-tested, and architecturally sound; the
testable seam is green and the acceptance criteria hold. It does not get a clean
PASS because the **frozen-contract spec revisions are not done**: DES-011
§3.4/§3.9, DES-012 §3.2/§3.4, and DES-013 §3.3 were required to be revised "in the
same change" as the code (DES-011 §6.3, DES-012 §6.3) and the plan's step 3
explicitly required driving the change through a frozen-contract revision. The
required changes below are mostly process/documentation, not code.

## Findings

### Blocking (required for the change to be contract-compliant)

**B1. Spec revisions are pending; the frozen contract was changed without them.**
The code adds public API to frozen surfaces — `ProviderConnectionService.modelKey(for:)`,
`updateModel(_:for:)`, `model(for:)`, `configure(_:endpoint:model:)` (DES-011),
`SettingsState.editingModel`/`ModelEditing` (DES-012 §3.2),
`SettingsSurface.configure(_:endpoint:model:)`/`updateModel(_:for:)`/`model(for:)`
(DES-012 §3.4), and the config-driven `preferredModels` (DES-013 §3.3) — before
the spec documents were amended. All three reports list "Spec revisions pending"
as remaining work, so the gap is known and documented, but the change process
(DES-011 §6.3, DES-012 §6.3, the plan §2/§10 "RFC/issue → spec revision →
implementation") requires the revision to ship with the code. Until the
revisions land, the implementation is not compliant with the frozen-contract
process. **Required change:** revise DES-011 §3.4/§3.9, DES-012 §3.2/§3.4, and
DES-013 §3.3 (additive model surface + the form/editor intents), in the same
change that is merged.

**B2. The Presentation layer consumes an Application API that DES-011 does not
yet specify.** DES-012 §3.4 states "The surface MUST consume only the frozen
`DES-011` settings surface." `SettingsSurface`/`RootView` call the model methods
of `ProviderConnectionService`, which are not in the frozen DES-011 §3.9 (only
the endpoint surface is). Functionally this is the intended design (the frozen
Application surface from step 1 is consumed, not redefined), but contractually
the seam violates §3.4 until the DES-011 §3.9 revision of B1 ships. Same fix as
B1.

### Required for accuracy (documentation)

**R1. The report's "additive only" claim for DES-012 is inaccurate.** The STEP3
report (Architecture Checks) says "Presentation (DES-012) gains additive members
only." Two changes are **modifications, not additions**, to public API on frozen
views: `ProviderConnectionFormView.onConfigure` changed from a
`(ConfigureProviderRequest, String)` closure to a `(ConfigureProviderRequest, String, String)`
triple (its public initializer signature changed, no two-arg overload retained),
and `SettingsView.init` gained three required parameters (`onEditModel`,
`onUpdateModel`, `onCancelModelEdit`, no overload retained). The plan mandated
the triple and the only consumer is `RootView`, so the change is contained and
intentional — but it is a breaking change to the frozen surface, not additive,
and DES-012 §6.3 requires additions to be backward-compatible. The pending spec
revision must authorize and record these signature changes explicitly (or an
additive overload should be retained). **Required change:** fold the signature
changes into the DES-012 revision; correct the "additive only" wording.

**R2. The report's "deviation from the plan" framing is partially inaccurate.**
The STEP3 report says the plan's step-3 sketch "noted no change to
`SettingsSurface`". The plan's own §8 mandates "extend `onConfigure` to a
`(ConfigureProviderRequest, String, String)` triple … and `SettingsSurface.configure`
accordingly" — so the `SettingsSurface.configure(_:endpoint:model:)` addition is
**required by the plan, not a deviation from it**. The genuine additions beyond
the plan are `SettingsState.editingModel`/`ModelEditing` (needed for the
pre-filled editor and for preserving input on failure, mirroring the endpoint
pattern — justified, but not mentioned in the plan) and the `SettingsView`
init/`onConfigure` signature changes. The deviation section should be rewritten
to attribute the plan-mandated part correctly. **Required change:** correct the
deviation narrative in the STEP3 report.

**R3. STEP2 report references non-existent spec files.** STEP2's
`related_documents` lists `Documentation/Design/DES-009.md`, `DES-011.md`,
`DES-013.md`; the spec files are named `DOMAIN_API.md`, `APPLICATION_API.md`,
`APP_API.md`. (STEP3's `related_documents` uses the correct filenames.)
**Required change:** fix the STEP2 front matter.

### Non-blocking (recommended)

**N1. Plan §9 Domain test case not added.** The plan suggested an
`OmniaDomainTests` case "where the combo is selected when it is the only offered
model". Not added. Selection of the recorded combo is covered at the app level
(`testPrepareSelectsTheRecordedModelWhenTheProviderRecordsOne`), so the coverage
exists one layer up; adding the Domain case is optional.

**N2. `remove(_:)` behavior change should be called out in the spec revision.**
`ProviderConnectionService.remove(_:)` now also removes the `providerModel`
key. This is expected cleanup and idempotent, but it is a behavior extension of
a frozen DES-011 §3.4 method and should be noted in the DES-011 revision (it is
currently documented only in the STEP1 report).

## Acceptance Criteria — Assessment (all met as implemented)

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Form collects optional model; empty records none → default | PASS | `ProviderConnectionFormView` model field; `RootView.configure` maps empty→nil; surface test `…_NilModelRecordsNoModel`; service test of the default fallback |
| 2 | Save records the model through `configure(_:endpoint:model:)` chain; credential only in `ConfigureProviderRequest` | PASS | Form → SettingsView → RootView → `SettingsSurface.configure(_:endpoint:model:)` → `ProviderConnectionService`; secret only in the request (ARC-005); surface test `…_RecordsTheModelAtProviderSettingsLevel` |
| 3 | Edit Model beside Edit Endpoint; pre-fill; empty rejected with typed error; failed update keeps editor open | PASS | `SettingsView` context menu; `ProviderModelEditorView` pre-fill via `currentModel`; surface test `…_EmptyModelSurfacesAsApplicationValidationError`; `RootView.failingSettingsState` preserves `editingModel` |
| 4 | RootView threads `onEditModel`/`onUpdateModel`/`onCancelModelEdit`; saves via the surface | PASS | Source review of `RootView` settings intents |
| 5 | New strings in both `Localized.swift` and `Localizable.strings`, following UI.md | PASS | `model`, `edit_model`, `save_model`, `update_model` present in both, alphabetical order; no new hardcoded user-visible strings in the new code |
| 6 | Linux suite green, no new warnings; SwiftUI review-only per DES-012 §3.7 | PASS | Re-verified on current tree: OmniaPresentation 199/199; full suite 0 failures; `ProviderConnectionFormView`/`ProviderModelEditorView`/`SettingsView`/`RootView` isolated behind `canImport(SwiftUI)` |
| 7 | No App/Domain/Infrastructure contract changed in step 3 | PASS (with B1/B2 caveat) | Step 3 touched Presentation only; DES-009/DES-010/DES-013 untouched by code; DES-011 model surface consumed, not redefined — but the DES-011/DES-012 revisions are pending |
| 8 | Nothing committed, pushed, or merged | PASS | `git status`: 15 modified, 5 untracked (plan + reports + `ProviderModelEditorView.swift`); no commits |

## Architecture — Assessment

- **ARC-001** — satisfied. A failed model update keeps the editor presented with
  its input retained (`RootView.failingSettingsState` preserves `editingModel`);
  failures surface as the typed `ApplicationValidationError`/`RepositoryError`,
  never wrapped (surface tests verify).
- **ARC-002 / ARC-004** — satisfied. The model is connection configuration, never
  a Domain aggregate value; `configure(_:endpoint:model:)` writes config only;
  no provider-specific code in the UI ("Model", not OmniRoute-specific).
- **ARC-005** — satisfied. The model is non-secret typed configuration at
  `.providerSettings`; the credential stays by reference and untouched.
- **ARC-006 / ARC-009** — satisfied. Composition unchanged; `SettingsSurface`
  remains the only Presentation seam to the Application service; `RootView`
  never touches `ProviderConnectionService` directly.
- **Dependency rules** — satisfied. OmniaPresentation imports only
  OmniaApplication/OmniaFoundation; the model vocabulary flows through the
  frozen `ProviderConnectionService` public API. Caveat is B2 (that API is not
  yet frozen in DES-011).
- **SwiftUI review (source-level)** — no compile-blocking issues found: all
  iOS-only modifiers (`.keyboardType`, `.textInputAutocapitalization`) are under
  `#if os(iOS)`; `.autocorrectionDisabled()`, `.foregroundStyle`,
  `Button(StringProtocol, action:)`, `.navigationTitle(String)` are
  iOS 15/macOS 12+ compatible. The model field sits above the Endpoint field in
  the form (report says "next to"); cosmetic, no change needed.

## Tests — Assessment

- 9 new `SettingsSurfaceTests` cover the additive surface: configure-with-model
  (records / nil records nothing / whitespace rejected before any write), read
  (`model(for:)` nil), update (records / trims / replaces / empty rejected with
  previous value preserved / repository failure surfaced as-is).
- 5 new `SettingsStateTests` cover `ModelEditing` default, flow, empty-current,
  and equality.
- Steps 1/2 coverage: 17 `ProviderConnectionServiceTests` and the App-level
  binding/selection tests (config-driven preferredModels, default fallback,
  explicit `providerUnavailable` for a combo provider).
- Re-verified on the current tree: OmniaPresentation 199/199. Earlier full-suite
  run on this tree: 0 failures, no warnings, `swift build` clean.
- Gap: the new `SettingsState`/`SettingsSurface` behavior is covered on Linux;
  the SwiftUI intents are review-only (§3.7), which is the documented convention.
- N1: plan's suggested Domain selection test case absent (non-blocking).

## What Must Change Before This Can Be Called Contract-Compliant

1. **B1/B2** — Land the DES-011 §3.4/§3.9, DES-012 §3.2/§3.4, DES-013 §3.3 spec
   revisions (additive model surface; authorize the form/editor intents) in the
   same change that is merged.
2. **R1** — Record the `onConfigure`/`SettingsView.init` signature changes as an
   authorized modification in the DES-012 revision (or retain additive
   overloads); fix the "additive only" wording in the STEP3 report.
3. **R2** — Correct the deviation narrative in the STEP3 report: the
   `SettingsSurface.configure(_:endpoint:model:)` triple is plan-mandated (§8);
   the genuine additions are `SettingsState.ModelEditing`/`editingModel` and the
   view signature changes.
4. **R3** — Fix STEP2 `related_documents` paths to the `*_API.md` filenames.

## Confirmed Non-Issues

- The `SettingsState` init is additive (`editingModel` has a `nil` default), so
  existing constructions compile unchanged — this part of the deviation is
  genuinely backward-compatible.
- The plan's Option-A validation tension (§5 "validated as a non-empty trimmed
  string" vs §8 "empty model is allowed") is resolved in favor of §8; the STEP3
  report documents this consistently, and the form allows an empty model while
  the editor rejects one.
- Localization is complete for the new strings; the pre-existing hardcoded form
  strings ("Connection", "Capabilities", "Limits", "Version", "API Key", etc.)
  are a pre-existing condition explicitly out of scope in the report.
- The recorded model is not displayed in the connection row (the editor
  pre-fills it on next edit); this matches the endpoint pattern and the plan
  makes the selector display optional — not a defect.
