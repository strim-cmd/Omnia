---
title: OmniRoute Integration — Step 2 Report (config-driven preferredModels)
document_id: OMNIROUTE-INTEGRATION-STEP2
version: 0.1.0
status: Implemented — Awaiting Review
created: 2026-08-09
project: Omnia
related_documents:
  - Documentation/Development/OMNIROUTE_INTEGRATION_PLAN.md
  - Documentation/Development/OMNIROUTE_INTEGRATION_STEP1.md
  - Documentation/Design/DOMAIN_API.md
  - Documentation/Design/APPLICATION_API.md
  - Documentation/Design/APP_API.md
---

# OmniRoute Integration — Step 2: config-driven `preferredModels`

## Summary

Step 2 of the OmniRoute integration makes the app-edge offered-models closure
config-driven: `CompositionRoot.preferredModels` now reads the per-provider
OpenAI-compatible model (the OmniRoute combo, or any provider model name)
recorded in step 1 at the `providerModel.<canonical>` key, falling back to the
app-edge default model when a provider records none. This closes the loop for
automatic selection and request routing: the same closure feeds both
`ProviderSelectionService` and `ProviderAdapterBinding`, so selection and
`readyProvidersOffering` now agree on the per-provider combo.

The hard-coded unconditional `[ModelReference(name: AppEdgeConstants.defaultModelName)]`
returned for every provider is removed.

## Changes

### `Packages/OmniaApp/Sources/OmniaApp/CompositionRoot.swift`

- Added the static seam `preferredModels(configurationService:)`, which returns
  the `@Sendable (ProviderIdentity) async -> [ModelReference]` closure the
  composition delivers to selection and to the binding. The closure reads
  `ProviderConnectionService.modelKey(for:)` at `.providerSettings` and returns
  `[ModelReference(name: model)]` when a model is recorded, otherwise
  `[ModelReference(name: AppEdgeConstants.defaultModelName)]`. A configuration
  read failure falls back to the app-edge default model — the same value a
  provider with no recorded model offers (ARC-001, DES-013 §3.3).
- `init` now constructs `configurationService` before the closure and passes
  `Self.preferredModels(configurationService:)` to both `ProviderSelectionService`
  and `ProviderAdapterBinding`. The `configurationService` and `preferredModels`
  construction order was swapped so the closure can capture the service.
- No public API surface changed: `CompositionRoot`'s public properties and
  `init(storageRoot:)` are unchanged; the new helper is internal.

### `Packages/OmniaApp/Sources/OmniaApp/AppEdgeConstants.swift`

- `defaultModelName` doc updated: it is now documented as the *fallback* model
  for a provider that records none, not the single model offered through every
  provider. The constant value (`omnia-coding`) is unchanged.

### Unchanged (preserved from step 1)

- `ProviderAdapterBinding` (DES-013 §3.3), `ProviderConnectionService`
  (DES-011 §3.9), the Domain selection contract (DES-009 §3.2), the frozen wire
  format (DES-010), and all Presentation surfaces (DES-012) are untouched.

## Tests

### `Packages/OmniaApp/Tests/OmniaAppTests/OmniaAppTests.swift`

- `FakeProviderAdapter` now records the model name of every request it serves
  (guarded by a lock), exposed as `models`.
- `RecordingAdapterFactory.adapterModels` forwards the recorded models, so tests
  assert exactly which model reached the adapter/request.
- `makeBinding` gained `model: String?` (records the model under
  `providerModel.<canonical>`) and `configDrivenPreferredModels: Bool` (uses the
  production `CompositionRoot.preferredModels(configurationService:)` closure
  instead of the fixed `[modelReference]` closure).
- New tests:
  - `CompositionRootTests.testPrepareSelectsTheRecordedModelWhenTheProviderRecordsOne`
    — a provider configured with `configure(_:endpoint:model:)` is selected with
    the recorded combo after `prepare()`.
  - `ProviderAdapterBindingTests.testGenerateTextServesTheRecordedModelWhenPreferredModelsAreConfigDriven`
    — with the config-driven closure, the combo recorded in configuration is the
    model of the request the adapter receives.
  - `ProviderAdapterBindingTests.testStreamServesTheRecordedModelWhenPreferredModelsAreConfigDriven`
    — same for the streaming path used by the send-message flow.
  - `ProviderAdapterBindingTests.testGenerateTextServesTheDefaultModelWhenNoModelIsRecordedAndPreferredModelsAreConfigDriven`
    — a provider with no recorded model falls back to the app-edge default.
  - `ProviderAdapterBindingTests.testThrowsProviderUnavailableWhenRequestingTheDefaultFromAComboProviderWithConfigDrivenPreferredModels`
    — a provider that records a combo no longer offers the default model; a
    request for the default fails explicitly (`CapabilityError.providerUnavailable`),
    so selection and routing stay consistent (ARC-001).

## Test Results (Linux suite, swift:6.0)

| Package | Executed | Failures |
|---|---|---|
| OmniaFoundation | 136 | 0 |
| OmniaDomain | 318 | 0 |
| OmniaApplication | 177 | 0 |
| OmniaInfrastructure | 187 | 0 |
| OmniaPresentation | 185 | 0 |
| OmniaApp | 39 (+5 new) | 0 |
| root skeleton | 1 | 0 |

`swift build --package-path Packages/OmniaApp`: no warnings.

## Architecture Checks

- **ARC-001** — a request for a model a combo provider no longer offers fails
  explicitly; selection and routing share the same closure, so they cannot
  disagree.
- **ARC-002 / ARC-004** — no business rule moved; the Domain selection contract
  is unchanged; the combo is app-edge configuration, not Domain or
  Infrastructure knowledge.
- **ARC-005** — the model is non-secret connection configuration, stored as a
  typed configuration value; the credential stays by reference.
- **ARC-006 / ARC-009** — composition remains the only assembler; the new
  `preferredModels` seam is internal and referenced from `CompositionRoot` only.
- **Frozen contracts** — Domain (DES-009), Infrastructure (DES-010), and
  Presentation (DES-012) untouched. Application (DES-011) and App (DES-013)
  surfaces gain additive behavior only; the DES-013 §3.3 spec revision remains
  pending (see below).

## Architectural Risks

- **Fallback-on-read-failure**: the non-throwing Domain closure signature
  (`ProviderSelectionService` contract, DES-009 §3.2) cannot surface a
  configuration read failure; the closure degrades to the app-edge default, the
  same value a provider with no recorded model offers. Mitigation: identical to
  the no-model case and documented in the closure doc; the binding still reads
  endpoint/credential with full error propagation, so a genuinely unavailable
  store surfaces at request time (ARC-001).
- **Default-model regression**: a provider that records a combo no longer offers
  `omnia-coding`; any existing configured provider is unaffected because none
  records a model until the step-3 UI writes one.
- **Spec revision pending**: DES-013 §3.3 and DES-011 §3.9 remain to be revised
  per the frozen-contract change process; additive only.

## What Remains

1. **Step 3 — presentation surface (DES-012):** generic optional "Model" field in
   `ProviderConnectionFormView`, an "Edit Model" action in `SettingsView`,
   threading `onUpdateModel`/`configure(_:endpoint:model:)` through `RootView`,
   and the new `Localized` keys. This is the only remaining step before a user
   can record a combo from the UI.
2. **Spec revisions:** DES-011 §3.4/§3.9 and DES-013 §3.3.
3. **Follow-up (Option B):** live combo listing via `GET {endpoint}/models` as a
   best-effort picker, kept optional behind manual entry.
