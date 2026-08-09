---
title: OmniRoute Integration — Step 1 Report
document_id: OMNIROUTE-INTEGRATION-STEP1
version: 0.1.0
status: Historical snapshot — Step 1 as implemented and verified at its close; superseded by STEP2, STEP3, and the spec revisions
created: 2026-08-09
project: Omnia
related_documents:
  - Documentation/Development/OMNIROUTE_INTEGRATION_PLAN.md
  - Packages/OmniaApplication/Sources/OmniaApplication/ProviderConnectionService.swift
  - Packages/OmniaApp/Sources/OmniaApp/ProviderAdapterBinding.swift
  - Packages/OmniaApplication/Tests/OmniaApplicationTests/ProviderConnectionServiceTests.swift
  - Packages/OmniaApp/Tests/OmniaAppTests/OmniaAppTests.swift
---

# OmniRoute Integration — Step 1 Report

> **Historical note.** This report is a snapshot of Step 1 as implemented and
> verified at its close. It is preserved unchanged as the record of that point
> in the integration. Where it reads as stale next to the final state, the
> later documents supersede it:
>
> - Its `DES-011 §3.9` references to the model surface predate the DES-011
>   v1.2.0 revision, which froze the model surface in **DES-011 §3.10** (the
>   endpoint surface remains §3.9).
> - The spec revisions it lists under "What Remains" were applied later, in
>   Step 3: DES-011 v1.2.0 (§3.10), DES-012 v1.2.0 (§3.2/§3.4/§3.6), and
>   DES-013 v1.1.0 (§3.3).
> - Its test counts are the Step-1 snapshot (OmniaPresentation 185, OmniaApp
>   34); the current tree is OmniaPresentation 199 and OmniaApp 39 per STEP2 and
>   STEP3. The counts below reflect the state at Step 1's close.
>
> See `OMNIROUTE_INTEGRATION_FINAL_REVIEW.md` for the final verdict.

## Summary

Step 1 of the OmniRoute integration is implemented: an optional per-provider
model (the OmniRoute combo, or any provider model name) can be recorded with a
provider connection through `ProviderConnectionService`, and the recorded model
is passed as the `model` of every OpenAI-compatible chat-completions request the
app-edge binding serves. The Linux regression suite is green across all six
packages and the root package (0 failures, 0 warnings). Nothing was committed or
pushed.

## Changes

### 1. `ProviderConnectionService` — optional per-provider model (DES-011 §3.9)

`Packages/OmniaApplication/Sources/OmniaApplication/ProviderConnectionService.swift`

- **`modelKey(for:)`** — new documented provider-settings configuration key
  `providerModel.<identity.canonicalString>`, mirroring `endpointKey(for:)`. The
  key is public because the Composition Root's runtime adapter binding reads the
  same key the settings surface writes (DES-004 — writers and readers never
  diverge).
- **`updateModel(_:for:)`** — records the model at the `.providerSettings` level.
  Boundary-validated (ARC-009): the trimmed value must be non-empty
  (`ApplicationValidationError.invalid` "The model is empty." otherwise).
- **`model(for:)`** — returns the recorded model, or `nil` when none is recorded.
- **`configure(_:endpoint:model:)`** — additive overload that validates the
  endpoint and, when given, the model before any write, then records both keyed
  by the fresh connection identity. `nil` records no model, so the provider
  falls back to the app-edge default.
- **`remove(_:)`** — now also removes the recorded model key.

The model is connection configuration the user owns (ARC-005); it never enters
the `ConfigureProviderRequest`, the `Provider` aggregate (DES-009 §3.1), or any
Domain value (ARC-004), exactly like the endpoint.

### 2. `ProviderAdapterBinding` — model passed into the OpenAI-compatible request (DES-013 §3.3)

`Packages/OmniaApp/Sources/OmniaApp/ProviderAdapterBinding.swift`

- The three capability methods (`generateText`, `sendMessage`, `stream`) now
  resolve the adapter bound to the serving provider and forward a request whose
  `ModelReference` is the provider's **recorded model** when one is recorded,
  or the caller's requested model unchanged otherwise.
- New private `model(for:)` reads the recorded model through
  `ProviderConnectionService.modelKey(for:)`.
- No DTO, transport, Domain contract, or `CapabilityMapping` change: the model
  name is already mapped to the wire `model` field by the existing adapter
  translation (DES-010 §3.9.2).

## Tests

### `ProviderConnectionServiceTests` (+17 tests)

- `updateModel` records at provider-settings level; trims; returns via `model(for:)`.
- `model(for:)` returns `nil` when nothing is recorded.
- Empty / whitespace-only model rejected before any write.
- Record and read failures surface as `RepositoryError` unchanged.
- `remove(_:)` removes the recorded model.
- `configure(_:endpoint:model:)`: records model keyed by the connection identity;
  `nil` records nothing; empty model rejected before any write; model-record
  failure surfaces as `RepositoryError`.

### `ProviderAdapterBindingTests` (+6 tests)

- A provider that records a model serves `generateText`, `sendMessage`, and
  `stream` with that model as the wire `model` (recorded on the fake adapter).
- A provider with no recorded model serves the caller's requested model unchanged.

### Suite results (Linux, `swift:6.0`, `the Linux CI container`)

| Package | Tests | Failures |
|---|---|---|
| OmniaFoundation | 136 | 0 |
| OmniaDomain | 318 | 0 |
| OmniaApplication | 177 | 0 |
| OmniaInfrastructure | 187 | 0 |
| OmniaPresentation | 185 | 0 |
| OmniaApp | 34 | 0 |
| root | 1 | 0 |

0 failures, 0 warnings; `swift build` on the modified packages emits no warnings.

## Architecture Checks

- **ARC-004** — provider API shape stays in OmniaInfrastructure; the combo name
  is just a `ModelReference.name`, no provider-specific code above the adapter.
- **ARC-005** — the model is non-secret connection config stored as a
  configuration value; the credential remains by reference and untouched.
- **ARC-006 / ARC-009** — composition is unchanged; the binding reads the same
  documented key the settings surface writes.
- **Frozen contracts** — no Domain (DES-009), Infrastructure (DES-010), or
  Presentation (DES-012) contract changed; Application (DES-011) and App
  (DES-013) surfaces gained additive members only. Spec revisions still needed
  (see below).
- **No UI, `preferredModels`, or `RootView` changes** — step 1 scope honored.

## What Remains for the Next Steps

1. **Step 2 — selection integration (DES-013):** make `CompositionRoot.preferredModels`
   read the per-provider recorded model so selection and `readyProvidersOffering`
   consider the combo, with the `omnia-coding` default as fallback. This closes
   the loop for automatic selection (currently the recorded model is honored only
   once a request reaches the binding).
2. **Step 3 — presentation surface (DES-012):** add the generic optional "Model"
   field to `ProviderConnectionFormView`, an "Edit Model" action in
   `SettingsView`, thread `onUpdateModel`/`configure(_:endpoint:model:)` through
   `RootView`, and add the new `Localized` keys.
3. **Spec revisions:** apply the additive revisions to DES-011 §3.4/§3.9 and
   DES-013 §3.3 per the frozen-contract change process.
4. **Follow-up (Option B):** live combo listing via `GET {endpoint}/models` as a
   best-effort picker, kept optional behind manual entry.
