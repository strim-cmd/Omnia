---
title: OmniRoute Integration Plan
document_id: OMNIROUTE-INTEGRATION
version: 0.1.0
status: Draft — Research Complete
created: 2026-08-09
project: Omnia
related_documents:
  - README.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - Documentation/Design/DOMAIN_API.md
  - Documentation/Design/INFRASTRUCTURE_API.md
  - Documentation/Design/APPLICATION_API.md
  - Documentation/Design/PRESENTATION_API.md
  - Documentation/Design/APP_API.md
  - project state
---

# OmniRoute Integration Plan

## Purpose

Record the research into how Omnia connects to providers today and the plan for
using OmniRoute — a local OpenAI-compatible gateway — as a provider: a selected
OmniRoute "combo" (a named routing rule upstream) is passed as the `model` in
every chat-completions request. The plan documents the current Provider /
AI-provider flow, the frozen contracts that constrain the change, where the
adapter and configuration live, how the combo is stored and transmitted, the
UI/UX surface, the tests, and the risks. It changes no code.

## 1. Current Provider / AI-provider Flow

### 1.1 Layering

| Layer | Responsibility | Provider-related surface |
|---|---|---|
| OmniaDomain | Contracts, aggregates, policies (ARC-002) | `Provider`, `ProviderConnection`, `ProviderIdentity`, `ProviderSelectionService`, `ProviderSelectionPolicy`, `ModelReference`, `ConfigurationKey` |
| OmniaApplication | Flows, orchestration (DES-011) | `ProviderConnectionService`, `ConfigureProviderRequest`, `SendMessageRequest`, `SendMessageUseCase`, `ConfigurationService` |
| OmniaInfrastructure | Provider APIs, transport (DES-010, ARC-004) | `OpenAICompatibleClient`, `OpenAICompatibleProviderAdapter`, `CapabilityMapping`, `ChatCompletionDTOs` |
| OmniaApp | Composition root, app edge (DES-013, ARC-006) | `CompositionRoot`, `ProviderAdapterBinding`, `AppEdgeConstants` |
| OmniaPresentation | SwiftUI view layer + surfaces (DES-012) | `ProviderConnectionFormView`, `ProviderEndpointEditorView`, `SettingsView`, `RootView`, `ConversationScreenView` |

### 1.2 The provider model

- A provider connection is the Domain aggregate `ProviderConnection`
  (identity, capabilities, metadata/display name, limits, version), stored by
  `ProviderRepository`. The credential is **never** in the aggregate — only a
  `CredentialReference` pointer (ARC-005).
- `ProviderLifecycleService` transitions stored connections to `.ready`.
- `ProviderSelectionService` (Domain actor) selects provider + model, honoring
  `userSelection` → `workspacePreference` → `capabilityPreference` → automatic,
  through the pure `ProviderSelectionPolicy` (DES-009 §3.2).

### 1.3 The model seam today

- `CompositionRoot.preferredModels` (CompositionRoot.swift:90) is a
  `@Sendable (ProviderIdentity) async -> [ModelReference]` closure returning
  `[ModelReference(name: AppEdgeConstants.defaultModelName)]` — the hard-coded
  string `"omnia-coding"` (AppEdgeConstants.swift:30) — for **every** provider.
- The same closure is injected into `ProviderSelectionService` (CompositionRoot.swift:93)
  and `ProviderAdapterBinding` (CompositionRoot.swift:101), so selection and
  request routing always agree on which models a provider offers (DES-013 §3.3).
- `ModelReference` is a plain `name: String`; that name becomes the wire
  `model` field of the chat-completions request via `CapabilityMapping`.

### 1.4 Request path

1. `SendMessageRequest` (conversation, message, optional selection preferences).
2. `SendMessageUseCase.send` appends/persists the user message, then selects
   via `selectionService.select(requiredCapability: .streaming, ...)` (SendMessageUseCase.swift:70).
3. The selection yields `(provider, model)`; a `StreamingRequest(history:model:)`
   is delivered to the streaming contract.
4. `ProviderAdapterBinding.stream` resolves the ready provider serving that model
   (`readyProvidersOffering`, ProviderAdapterBinding.swift:138), reads the
   recorded endpoint and credential reference from provider-settings config,
   constructs an `OpenAICompatibleProviderAdapter`, and forwards the request.
5. `CapabilityMapping` maps `ModelReference.name` → `model` in
   `ChatCompletionRequest`; `OpenAICompatibleClient` POSTs
   `{endpoint}/chat/completions` with `Authorization: Bearer` and decodes SSE
   chunks (OpenAICompatibleClient.swift:33-70).

### 1.5 What exists today for arbitrary OpenAI-compatible endpoints

- The connection form collects display name, endpoint, API key, capabilities,
  limits, version (ProviderConnectionFormView.swift).
- `ProviderConnectionService` validates the endpoint as an absolute `http(s)`
  URL (ProviderConnectionService.swift:179) and records it at the
  provider-settings configuration level under the documented key
  `providerEndpoint.<canonical>` (`endpointKey(for:)`, ProviderConnectionService.swift:144).
- The credential is stored by reference (`providerCredential.<canonical>`
  key, ProviderConnectionService.swift:133) in `SecureCredentialStorage`
  (Keychain on Apple; in-memory on Linux).
- **There is no per-provider model concept.** Every provider offers the same
  hard-coded `omnia-coding` model. There is also no model listing anywhere.

## 2. Frozen Contracts and Constraints

- **PRODUCT_CHARTER.md:275** — "Omnia never proxies AI traffic." Using a local
  OmniRoute gateway does not violate this: the endpoint is user-supplied, the
  traffic still goes straight from Omnia to the user's own gateway, and Omnia
  routes nothing between providers (PRD-000:340).
- **PRODUCT_CHARTER.md:283** — "Any OpenAI-compatible endpoint can be used
  without changing the application." OmniRoute is exactly such an endpoint; the
  README already lists OmniRoute among supported providers (README.md:102).
- **DES-009 (Domain API, frozen v1)** — provider model, capability contract,
  selection policy. `ModelReference` and `ProviderSelectionService` are frozen.
- **DES-010 (Infrastructure API, frozen v1)** — provider APIs never leave the
  package; `OpenAICompatibleClient`/`OpenAICompatibleProviderAdapter` are the
  only provider implementations (ARC-004).
- **DES-011 (Application API, frozen v1)** — `ProviderConnectionService` flows
  and config keys; endpoint/credential collection is §3.9.
- **DES-012 (Presentation API, frozen v1)** — forms/surfaces are §3.4.
- **DES-013 (App API, frozen v1)** — composition root wiring is §3.3.
- **PRODUCT_PRINCIPLES (PRD-001)** — Provider Independence: no provider-specific
  UI, no excessive configuration; the interface stays generic.
- **ARC codes** — ARC-002 (Domain owns rules), ARC-004 (provider APIs internal to
  Infrastructure), ARC-005 (credentials by reference), ARC-006/ARC-009
  (composition root is the only assembler), ARC-001 (no silent failures).
- **DocumentationStandard / change process** — any API change to a frozen spec
  requires a spec revision via RFC/issue, per the established process.

## 3. Where the Adapter Goes

**No new adapter is needed.** OmniRoute is OpenAI-compatible, so the existing
`OpenAICompatibleProviderAdapter` + `OpenAICompatibleClient` already speak to it.
The integration is a **configuration + selection** concern, not an
infrastructure concern:

- OmniRoute "combos" are just names that OmniRoute routes upstream; to the
  OpenAI-compatible API they are exactly the `model` field.
- Therefore the change is: (a) let the user record a per-provider **model name**
  (the combo), and (b) make `preferredModels` return that name so selection and
  routing use it. The wire format, DTOs, transport, and adapters are untouched.

## 4. Storage of Endpoint, API Key, and Combo

| Value | Level | Key | Writer / Reader |
|---|---|---|---|
| Endpoint | providerSettings | `providerEndpoint.<canonical>` | `ProviderConnectionService.updateEndpoint` / `ProviderAdapterBinding` |
| Credential ref | providerSettings | `providerCredential.<canonical>` | `ProviderConnectionService.configure` / `ProviderAdapterBinding` (secret itself in `SecureCredentialStorage`) |
| **Combo (model name)** | providerSettings | **`providerModel.<canonical>` (new)** | new `ProviderConnectionService.model`/`updateModel` / `CompositionRoot.preferredModels` |

The combo follows the exact endpoint pattern: a static
`modelKey(for:) -> ConfigurationKey<String>` scoped by identity
(ProviderConnectionService.swift:144-148), recorded at `.providerSettings` by a
new `updateModel(_:for:)` and read by `preferredModels`. Storing it as
configuration — not on the `Provider` aggregate — preserves the frozen aggregate
(DES-009 §3.1) and ARC-004, exactly like the endpoint today.

## 5. Getting / Showing Combos

Two options:

- **Option A (recommended, no infrastructure change): manual entry.** The
  connection form and settings gain an optional "Model / Combo" text field. The
  user types the combo name; it is validated as a non-empty trimmed string
  (like the endpoint) and stored per-provider. Simple, universal, works for
  every OpenAI-compatible gateway, and needs no new provider API call.
- **Option B (future enhancement): live listing via `GET {endpoint}/models`.**
  `OpenAICompatibleClient.probeAvailability` (OpenAICompatibleClient.swift:79)
  already calls `/models` but discards the body. A new internal
  `listModels(endpoint:credential:)` could decode `{"data": [{"id": ...}]}` and
  surface the combo names for a picker. This requires a DES-010 addition
  (Infrastructure contract) and is best-effort (some gateways omit or error on
  `/models`), so Option A stays the fallback.

## 6. Passing the Combo as `model`

`ModelReference.name` is already the wire `model`. So passing a combo is simply
making `preferredModels` return it:

- `CompositionRoot.preferredModels` (CompositionRoot.swift:90) reads the
  per-provider combo from `configurationService`:
  `combo ?? ModelReference(name: AppEdgeConstants.defaultModelName)`.
  Because the **same closure** feeds selection and the binding, the combo flows
  through untouched: selection picks the combo, `StreamingRequest.model` carries
  it, `readyProvidersOffering` matches it, `CapabilityMapping` writes it as
  `model`. **Zero changes to Domain contracts, DTOs, or the transport.**

## 7. Genericity Across OpenAI-Compatible Gateways

The change is deliberately **not OmniRoute-specific**:

- The configuration key and the form field are generic ("Model"), valid for
  OpenAI, OmniRoute, Ollama, OpenRouter, LM Studio, LocalAI, vLLM, Groq, Together
  AI (README.md:99-109).
- No provider identity or name appears in Domain, Infrastructure, or the wire
  format; `omnia-coding` remains only as the default fallback constant.
- No new capability is declared; the existing capability toggles apply unchanged.
- This honors PRODUCT_PRINCIPLES (Provider Independence) and keeps the UI
  generic — a user configures "a provider with a model", never "an OmniRoute".

## 8. UI / UX Changes

- **ProviderConnectionFormView** (ProviderConnectionFormView.swift): add an
  optional "Model" `TextField` (autocorrection disabled, no autocap, `.URL`/never
  keyboard style) in the Connection section. Extend `onConfigure` to a
  `(ConfigureProviderRequest, String, String)` triple (request, endpoint, model)
  and `SettingsSurface.configure` accordingly; empty model is allowed (falls back
  to the default).
- **SettingsView** (SettingsView.swift:43, :89): add a model editor beside the
  endpoint editor — either a second sheet reusing `ProviderEndpointEditorView`
  or an "Edit Model" entry; wire `onUpdateModel: (ProviderIdentity, String) -> Void`.
- **RootView** (RootView.swift:204, :522): thread the model through
  `configure(_:endpoint:model:)` and add `updateModel`.
- **ConversationScreenView** provider selector: unchanged in behavior; the model
  display may optionally show the combo name as secondary text.
- **Localized.swift**: new keys for "Model", "Model / Combo", "Edit Model".
- Follow `project UI standards` (iOS 15/macOS 12 availability, validation message
  pattern, no provider-specific text).

## 9. Tests

- **OmniaAppTests** (`ProviderAdapterBindingTests`, OmniaAppTests.swift:277):
  a provider whose `preferredModels` returns the combo is resolved and the
  adapter is constructed with its recorded endpoint; a provider with no combo
  falls back to the default model.
- **OmniaDomainTests** (`ProviderSelectionServiceTests`:39): the `preferredModels`
  closure pattern already covers per-provider model lists; add a case where the
  combo is selected when it is the only offered model.
- **OmniaApplicationTests**: `ProviderConnectionService.model`/`updateModel`
  store/read/remove the `providerModel.<canonical>` key at providerSettings;
  empty/whitespace model handling; `remove(_:)` also clears the model key.
- **OmniaInfrastructureTests**: unchanged unless Option B (decode `/models`).
- **Linux suite** stays green; the SwiftUI form additions are review-only per
  existing convention (§3.7).

## 10. Risks and Spec Changes

| Risk / change | Impact | Mitigation |
|---|---|---|
| Spec changes | DES-011 §3.4/§3.9 (`updateModel`, `modelKey`, `configure(_:endpoint:model:)`), DES-012 §3.4 (form/settings), DES-013 §3.3 (preferredModels config-driven) | Follow the frozen-contract revision process (RFC/issue → spec revision → implementation); changes are additive, not breaking |
| Default model constant | `AppEdgeConstants.defaultModelName` becomes only the fallback | Keep the constant; document that per-provider models override it |
| `/models` listing varies by gateway | Option B may return partial/empty lists | Option A (manual entry) is the primary path; Option B is best-effort |
| Combo name vs capability mismatch | A combo may route to a model lacking a declared capability | Same risk as today with the hard-coded model; surfaced by transport errors (ARC-001) |
| No code change scope creep | Plan says "no adapter, no DTO change" | Explicitly out of scope; any needed Infrastructure change is a separate RFC |

## Summary

OmniRoute is already a supported OpenAI-compatible endpoint. The only missing
piece is a per-provider **model name** (the combo) that is passed as the wire
`model`. Because `preferredModels` already feeds both selection and the adapter
binding, the whole integration is: a new `providerModel.<canonical>` config key
recorded by `ProviderConnectionService`, a generic optional "Model" field in the
connection form/settings, and a `CompositionRoot.preferredModels` closure that
returns the recorded combo (falling back to `omnia-coding`). No new adapter, no
DTO change, no Domain contract change. The UI and selection remain generic for
every OpenAI-compatible gateway.

## Recommended Next Step

Implement the additive change in order: (1) `ProviderConnectionService` model key
+ `updateModel` + `configure(_:endpoint:model:)` with tests (DES-011 revision);
(2) `CompositionRoot.preferredModels` reads the combo with the default fallback
(DES-013 revision) + `ProviderAdapterBinding` tests; (3) presentation surface
`onUpdateModel` + form field + RootView threading (DES-012 revision) with
Localized keys. Drive each through the standard issue → PR flow with a frozen-contract
revision per the DocumentationStandard, and keep Option B (`/models` listing) as
a tracked follow-up.
