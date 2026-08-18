# Omnia v1.0.0 — Autonomous Execution Scope

## 1. Mission

Take Omnia from its current working pre-1.0 state to a device-testable **v1.0.0 Release Candidate** by completing these milestones in order:

1. **M1 — Models + Provider Capabilities**
2. **M2 — Attachments / Multimodal Input**
3. **M3 — Conversation Management + Markdown + Errors**
4. **M4 — Settings / Onboarding / Persistence / Security Polish**
5. **M5 — v1 Release Candidate**

This file is the execution contract. For every milestone, work continuously:

~~~text
INSPECT CURRENT STATE
    ↓
IMPLEMENT THE MILESTONE
    ↓
RUN TARGETED AND FULL RELEVANT TESTS
    ↓
PERFORM ONE FOCUSED AUDIT
    ↓
FIX EVERY P0/P1 FINDING
    ↓
RE-TEST AND RE-CHECK THE FIXED AREA
    ↓
COMMIT AND PUSH
    ↓
START THE NEXT MILESTONE
~~~

Do not stop between milestones to ask what to do next. Stop only for a genuine external blocker or a product decision that cannot be resolved from repository specifications and existing behavior.

After M5, set the app version to **1.0.0**, complete release metadata, run the authoritative GitHub Actions Apple build, produce and verify the **unsigned IPA artifact**, and provide a physical-device test checklist.

---

## 2. Explicit Post-v1 Boundary: the Short-Prompt Framework

The previously built short-prompt / intent-driven engineering framework under **.ai/** is explicitly **not part of Omnia v1.0.0 product delivery**.

During M1–M5:

- do not extend, redesign, migrate, clean up, or “finish” the short-prompt framework;
- do not make v1 product code depend on new framework work;
- do not delete the framework or invalidate its existing history;
- do not run framework-wide validation unless a repository-required product gate explicitly invokes it;
- touch it only if a mandatory existing check cannot run without a minimal compatibility correction, and keep that correction isolated.

Record desired framework improvements in a **post-v1.0 backlog**. Resume them only after a stable product v1.0.0 release.

This deferral includes prompt-library, prompt-marketplace, workflow-orchestration, short-command expansion, and related framework work. None may delay M1–M5.

---

## 3. Protected Working Baseline

Treat these already implemented and confirmed areas as a protected baseline:

- conversation creation, list, open/switch, search, deletion, history persistence, and restoration;
- streaming generation and thinking, streaming, completed, interrupted, and error states;
- explicit Stop/Cancel and Retry/Resume/Continue behavior;
- partial-response preservation;
- generation ownership that survives conversation switching and screen navigation;
- conversation-ID isolation for stream chunks;
- view disappearance and temporary inactive/background transitions do not voluntarily cancel generation;
- provider add/edit/remove, endpoint/model fields, secure credential storage, lifecycle/readiness, and active-provider selection;
- the generic OpenAI-compatible provider path;
- conversation UI, adaptive composer, keyboard dismissal, adaptive message bubbles, message actions, side menu, themes, navigation, and localization mechanism;
- the layered package architecture and composition root;
- the deterministic test suite;
- the Apple GitHub Actions release pipeline and credential-free unsigned iOS artifact path.

These are not permission for another redesign.

Modify a protected area only when:

1. a milestone requires a narrow extension at its existing contract boundary; or
2. a reproducible regression blocks a milestone acceptance criterion.

When one must change:

- identify the exact regression or contract extension;
- make the smallest compatible change;
- add a regression test;
- preserve all previously confirmed behavior.

Do not create parallel navigation, persistence, generation, provider-lifecycle, credential, theme, or UI architectures.

---

## 4. Repository and Architecture Rules

Before the first edit of each milestone, inspect only the relevant current state:

- repository instructions and Git status;
- product, architecture, design, and development documents relevant to that milestone;
- affected package manifests, code, and tests;
- CI/release configuration when M5 begins.

Current tested production behavior takes precedence over obsolete prose. Reconcile outdated documentation carefully; do not resurrect removed components merely because an old document names them.

Preserve established ownership:

~~~text
Presentation: render state and translate user intent
Application: orchestrate use cases and transaction boundaries
Domain: own stable product concepts and invariants
Infrastructure: own transport, persistence, file storage, credentials
App/composition: wire dependencies and stay thin
~~~

Follow the actual package manifests for exact dependency direction.

Mandatory rules:

- SwiftUI views do not own networking, persistence, provider business logic, or long-lived generation tasks.
- Prefer Apple/Foundation APIs and existing abstractions.
- Add no third-party dependency without a concrete documented need.
- Add no mutable global singleton or second source of truth.
- Add no fake production success path, hardcoded model catalog, disabled test, swallowed error, or provider-name UI fork merely to make tests green.
- Never expose credentials, authorization headers, message/attachment contents, or secrets in logs.
- Preserve existing stored conversations and providers through backward-compatible decoding or a tested migration.
- Do not claim Apple/device behavior from Linux-only validation.

At the time this scope was authored, **Documentation/UI/FIX_UI.md** was an unrelated untracked file. Treat it and every other pre-existing modified/untracked file as user-owned. Do not edit, stage, commit, delete, or overwrite them unless explicitly authorized.

---

## 5. Autonomous Operating Protocol

### 5.1 Milestone preflight

At the start of each milestone:

1. inspect branch, HEAD, remotes, and working tree;
2. identify user-owned changes and keep them out;
3. compare with the tracked remote when network access is available;
4. read only relevant specifications, code, and tests;
5. identify current contracts and missing acceptance behavior;
6. make a concise implementation plan;
7. proceed directly to implementation.

Do not produce a general repository or UI audit.

### 5.2 Implementation

- Implement vertical slices through existing layers.
- Prefer additive, backward-compatible contracts.
- Keep changes milestone-specific.
- Preserve platform floors and supported Apple targets.
- If a provider/model lacks a required capability, expose that truth rather than silently degrading.
- Do not narrow the milestone silently because one provider or platform is inconvenient.

### 5.3 Validation

Run the strongest available checks:

- focused tests for changed behavior;
- affected package suites;
- the full standard suite and root package tests;
- relevant build/static checks;
- git diff --check;
- an Apple build when Xcode is available;
- the authoritative GitHub Actions Apple build at M5.

Tests must be deterministic:

- network is mocked in tests;
- no arbitrary sleeps;
- state transitions, persistence round trips, typed errors, races, and redaction are asserted;
- source-text assertions do not replace behavioral tests when behavior is testable;
- no production fake exists only for tests.

### 5.4 Focused audit and priorities

After green validation, perform exactly **one focused audit for that milestone**.

Classify findings:

- **P0 — Release blocker:** data loss/corruption, credential exposure, primary-flow crash, unusable primary flow, cross-conversation data leakage, or compromised artifact.
- **P1 — Milestone blocker:** required criterion missing or materially broken, wrong capability routing, duplicate requests/messages, persistence incompatibility, inaccessible required flow, or serious deterministic regression.
- **P2 — Non-blocking:** real but limited polish/maintainability issue that does not invalidate the milestone.

Fix every P0/P1. Re-run affected tests and re-check only the corrected area. Do not restart a broad audit loop.

P2 does not block completion. Fix it only if small, low-risk, and in scope; otherwise record it for post-v1.

### 5.5 Commit, push, continue

When there are zero open P0/P1 findings, required tests are green, and no unrelated files are staged:

1. inspect git status --short;
2. inspect git diff --stat;
3. run git diff --check;
4. stage only milestone files;
5. inspect git diff --cached --stat and the staged diff;
6. create a coherent milestone commit, or the smallest necessary coherent sequence;
7. push the tracked branch, normally origin/main;
8. confirm local/remote synchronization;
9. immediately start the next milestone.

Never include user-owned files. Never force-push or rewrite published history.

### 5.6 Legitimate stop conditions

Stop only when:

- two materially different user-facing choices remain valid and repository sources do not resolve them;
- a destructive migration could lose existing data and no safe policy exists;
- required external access is unavailable after repository-local alternatives are exhausted;
- remote conflicts cannot be integrated safely without user direction;
- an Apple/device-only fact blocks a truthful release claim.

Apple signing credentials, App Store Connect, provisioning profiles, notarization, TestFlight, and App Store distribution are **out of scope, not blockers**. The required artifact is unsigned.

When blocked, report evidence, completed work, and the smallest user action needed.

---

# M1 — Models + Provider Capabilities

## Objective

Deliver first-class provider/model selection with truthful capabilities, stable defaults, per-conversation selection, connection validation, and no accidental model changes across navigation or relaunch.

M1 is the foundation for M2. Attachments stay unavailable until Omnia can determine whether the selected provider/model accepts them.

## Inspect

Inspect existing:

- provider connection/capability domain models;
- lifecycle/readiness and selection services;
- endpoint/model configuration and repositories;
- model-preference configuration;
- OpenAI-compatible transport/request builders;
- send-message provider/model resolution;
- Settings and chat selectors;
- conversation persistence;
- error mapping and tests.

Determine which facts are provider-wide, model-specific, user-declared, endpoint-discovered, or currently only a string.

## Required behavior

### Model catalog and identity

- Introduce or complete a stable model descriptor/identity at the correct layer.
- Load provider models through the existing generic OpenAI-compatible path when discovery is supported.
- Do not hardcode a vendor catalog as production truth.
- Preserve a configured/manual model fallback when discovery is unsupported/unavailable.
- Represent loading, loaded, empty, unavailable, stale/cached, and failed states where user action differs.
- Refresh without destroying a valid saved selection.
- Never switch silently because list ordering changes.

### Capability model

Represent the v1 capabilities at the narrowest truthful level:

- text generation/conversation;
- streaming;
- image/vision input;
- file/document input;
- existing required generic capabilities already modeled by Omnia.

Rules:

- do not flatten model-specific facts into an inaccurate provider-wide promise;
- provider transport support and model input support must both be respected;
- generic model-list responses often do not prove vision/file support, so missing metadata remains unknown/conservative rather than guessed;
- user-declared overrides or repository compatibility metadata must be explicit, persisted, and distinct from discovered facts;
- capability gating stays generic, with no provider-name switch forest.

### Selection and persistence

- Provide a usable Model Selector in chat.
- Changing provider shows only that provider’s models.
- Support default provider and default model.
- Persist provider/model per conversation.
- New conversations inherit valid defaults.
- Existing conversations retain recorded selection.
- Navigation, rapid A → B → A, background/foreground, and relaunch do not change a conversation’s model.
- If a saved model is unavailable, explain and require explicit replacement; do not silently route elsewhere.

### Provider validation

- Add/complete **Test Connection** in Add/Edit Provider.
- Validate the real endpoint/credential path without logging secrets.
- Distinguish invalid credential/unauthorized, unreachable/no network, invalid endpoint, model unavailable, rate limit, timeout, and server failure when evidence exists.
- A failed test preserves form data.
- Ready cannot mean only that required fields are non-empty.

### Generation integration

- Send through the explicitly resolved provider/model.
- Enforce effective capabilities before request start.
- Preserve existing generation lifecycle, cancellation, partial content, and conversation isolation.
- Prevent duplicate sends during incompatible model-resolution/validation state.

## Required tests

Cover at least:

- model-list decoding and transport/error mapping;
- discovery unsupported/empty/offline/unauthorized/rate-limited;
- configured fallback;
- selection stability across refresh/reordering;
- default inheritance;
- per-conversation provider/model save/reload;
- provider switch without cross-conversation corruption;
- unavailable saved model requires explicit action;
- conservative unknown capabilities;
- capability precedence/persistence;
- Test Connection success and typed failures;
- no credential in error/debug/log descriptions;
- send uses intended provider/model;
- rapid navigation cannot cross-assign model state;
- existing lifecycle/generation regressions.

## Focused audit

Audit only model identity/catalog, capability truthfulness, selection/default/persistence, validation/redaction, routing changes, migration, and M1 tests.

## Completion gate

A user can configure/test a provider, choose provider/model, see truthful feature availability, retain the choice per conversation across relaunch, and send to that exact selection. Tests are green; P0/P1 count is zero.

Suggested commit:

~~~text
feat(models): add model selection and provider capabilities
~~~

---

# M2 — Attachments / Multimodal Input

## Objective

Deliver a complete attachment pipeline for photos, images, PDFs, and supported text documents: picker → preview → capability validation → provider request → persistence/cleanup.

## Inspect

Inspect existing:

- composer attachment button/state;
- message/domain content model;
- drafts and conversation persistence;
- provider request/content parts;
- M1 capability resolution;
- storage abstractions;
- platform file/photo pickers;
- size limits, errors, localization.

Do not redesign the composer.

## Required behavior

### Picking and staging

- Support Photos and Files with native Apple pickers appropriate to each target.
- Support common image formats, PDF, and defined safe plain-text formats.
- Allow multiple attachments up to explicit tested count/size limits.
- Copy temporary/security-scoped input into app-owned storage when durable access is needed.
- Never retain a temporary external URL as the sole durable reference.
- Reject unsupported, unreadable, empty, excessive, or unsafe input with a human-readable error.

### Composer experience

- Show accessible preview/chips before send.
- Show safe filename/type/size, never full private paths.
- Show image thumbnails where practical.
- Remove any staged item before send.
- Preserve draft text on success, cancellation, and picker error.
- Prevent duplicate records from repeated selection.
- Preserve existing adaptive composer, keyboard, Send/Stop, safe-area, and navigation behavior.

### Capability gating

- Evaluate every item against the selected provider/model’s effective capabilities.
- Disable or explain unsupported input before request start.
- Re-evaluate immediately when provider/model changes.
- Never silently drop an attachment or send one to a model known not to accept it.
- Handle unknown support conservatively with an explicit explanation or declared-capability path.

### Content and transport

- Attachments are first-class message/request content, not a UI-only array.
- Preserve text-plus-attachment ordering/semantics required by the contract.
- Encode images through the generic OpenAI-compatible request path.
- Handle PDF/text through a repository-approved explicit strategy supported by the selected model/transport. Do not pretend a generic models response proves native file input.
- If bounded local text extraction is used, keep metadata, enforce size/token limits, surface failures, and do not claim OCR unless implemented/tested.
- Keep provider transport details out of Presentation and Domain UI state.
- Validate before loading arbitrary files; bound memory usage.

### Send, persistence, cleanup

- Successful send associates metadata with the correct user message/conversation.
- Persist minimum durable metadata/reference for history.
- Do not store credentials, sandbox-only external paths, or giant base64 blobs in main conversation JSON unless the existing storage design explicitly requires/tests it.
- Define/test ownership, deletion, retry/resume, and orphan cleanup.
- Conversation deletion removes only exclusively owned files.
- Failure does not corrupt history or destroy appropriate retry input.
- Relaunch creates no duplicate message/attachment records.

### Accessibility/privacy

- Meaningful accessibility labels/hints and VoiceOver order.
- Dynamic Type remains usable.
- Never log file content, image data, full private path, or document text.
- Errors contain only safe metadata.

## Required tests

Cover at least:

- UTType/MIME/type detection;
- per-file, aggregate, and count limits;
- temporary/security-scoped copy to durable storage;
- duplicate picker results;
- add/remove behavior;
- capability accept/reject for image, PDF, text;
- provider/model change revalidation;
- encoding text plus one/multiple images;
- PDF/text strategy limits and failures;
- metadata save/reload;
- retry/interruption without duplicates;
- conversation deletion/orphan cleanup;
- no cross-conversation leakage;
- error redaction;
- composer/generation regressions.

## Focused audit

Audit only picker/staging lifecycle, capability gating, encoding, bounded storage/memory, persistence/cleanup/privacy, composer regressions introduced by M2, and tests.

## Completion gate

Users can attach supported photos/files, inspect/remove before send, receive clear validation, send through the correct provider/model, reopen coherent metadata, and delete without leaks/orphans. P0/P1 count is zero.

Suggested commit:

~~~text
feat(attachments): add capability-aware multimodal input
~~~

---

# M3 — Conversation Management + Markdown + Errors

## Objective

Finish daily chat UX without rewriting the stable generation engine: conversation organization, robust Markdown/code rendering, and actionable human-readable failures.

## Inspect

Inspect existing conversation list/search/swipe/delete/new-chat behavior, metadata/timestamps/titles, Markdown renderer, error mapping, recovery actions, per-conversation settings, localization, accessibility, and tests.

## Required behavior

### Conversation management

- Explicit rename persists.
- Automatic title for an untitled chat never overwrites user rename.
- Preserve search and deletion.
- Deterministic, discoverable swipe actions.
- Correct local-time groups: Today, Yesterday, Previous 7 Days, and suitable older grouping.
- Consistent timestamps and sorting.
- New conversation from every expected entry point without duplicates/orphans.
- Selection stays stable on unrelated metadata updates.
- Deterministic delete behavior for selected or actively generating conversation; unrelated state is never lost.
- Per-conversation provider/model and any implemented system instruction persist.

### Markdown and code

Support/verify:

- paragraphs and line breaks;
- headings;
- ordered/unordered lists;
- block quotes and emphasis;
- safe links;
- inline code;
- fenced blocks with language label when present;
- horizontal scrolling for long code;
- Copy Code;
- whole-message copy;
- large answers;
- safe incremental streaming rendering.

Invalid/incomplete streaming Markdown degrades safely and recovers. Arbitrary HTML/scripts never execute. Selection, links, scrolling, copy, message actions, and keyboard dismissal remain compatible. Extend the existing renderer; do not add a parallel one without proof it is necessary.

### Errors

Map failures to stable user-facing categories:

- offline/unreachable;
- unauthorized/invalid API key;
- invalid endpoint;
- invalid/unavailable model;
- unsupported capability/attachment;
- timeout;
- rate limit;
- server error;
- malformed response;
- interrupted stream;
- local persistence/file error.

For each:

- localized human-readable message;
- safe diagnostic detail without secrets;
- correct action where meaningful: Retry, Continue, Change Model, Edit Provider, Remove Attachment, Dismiss;
- no retry that duplicates a completed request;
- partial content and interruption semantics preserved;
- no duplicate user/assistant messages.

### Generation regression guard

Verify but do not redesign Stop, Retry, Resume/Continue, Regenerate if present, network interruption, duplicate protection, A → B → A, navigation/background non-cancellation, and late-chunk rejection. Change ownership only for a reproducible regression with a narrow test.

## Required tests

Cover at least:

- rename persistence and user-title precedence;
- auto-title and failure fallback;
- grouping at midnight/calendar/locale boundaries and old/future dates;
- sort/selection stability;
- delete selected/active behavior;
- new-chat idempotence;
- persisted conversation settings;
- Markdown fixture for every construct;
- incomplete/invalid streaming Markdown;
- long fenced code and Copy Code state;
- safe link behavior;
- typed mapping for every error category;
- contextual recovery actions;
- no secret leakage;
- retry/resume without duplicates;
- existing generation isolation/cancellation tests.

## Focused audit

Audit only conversation organization, Markdown/code/interaction, error taxonomy/actions/redaction/localization, generation regressions touched by M3, and tests.

## Completion gate

Conversation organization is predictable, Markdown/code is usable for real output, and common failures have truthful recovery without duplication, data loss, or secret exposure. P0/P1 count is zero.

Suggested commit:

~~~text
feat(chat): complete conversation markdown and error experience
~~~

---

# M4 — Settings / Onboarding / Persistence / Security Polish

## Objective

Make Omnia reliable from first launch through long-term local use: coherent settings/defaults, non-dead-end onboarding, migration-safe state, localization/accessibility, and v1-grade data/credential handling.

## Inspect

Inspect Settings/Providers, configuration services, first-launch/empty-provider flow, serializers/repositories, credential storage/deletion, drafts/partial/attachment storage, clear-data paths, About/version, localization, accessibility, and tests.

## Required behavior

### App settings

- Default provider.
- Default model constrained to that provider.
- Existing appearance behavior; add System only if repository specifications already call for it.
- In-app language only if existing architecture supports it; otherwise ensure system-language localization and avoid a parallel localization system.
- Clear route to provider/credential management with no duplicate credential form.
- Clear Conversations/Data with explicit destructive confirmation and precise scope.
- Deterministic save/restore.
- Invalid defaults identify themselves and require correction; no silent redirect.

### Onboarding/empty setup

- First launch without provider has a clear Add Provider CTA.
- Flow continues through provider entry, Test Connection, default/active model, and usable chat.
- Send never enters dead/fake loading without a ready provider/model.
- Cancel/back leaves recoverable state.
- Existing users do not see onboarding again due to migration or transient failure.
- Empty/loading/failure states provide a useful next action.

### Persistence integrity/migration

Complete/verify persistence for:

- conversations/messages;
- titles/timestamps;
- provider/model association;
- attachment metadata/files;
- partial/interrupted messages;
- drafts where required by existing UX;
- defaults/appearance;
- onboarding completion if stored.

Requirements:

- decode pre-v1 data;
- explicit defaults for new fields;
- tested migration and round trips;
- atomic/deterministic writes through existing abstractions;
- recover malformed individual records where architecture permits without silently wiping everything;
- no duplicates after relaunch, retry, migration, or crash recovery;
- no second persistence source for the same state.

### Security/privacy

- API keys/tokens remain in secure credential storage, never plaintext config/conversation files.
- Provider records contain only safe metadata/credential references.
- Provider deletion removes only its credential material/reference as designed.
- Provider editing does not orphan/expose old secrets.
- Clear Data has explicit tested behavior for chats, attachments, settings, credentials.
- Logs, errors, debug descriptions, diagnostics, and UI reveal no secrets or private content.
- No certificates, provisioning profiles, private keys, real fixture credentials, or device data enter Git.
- Add no analytics/remote telemetry.
- Do not invent entitlements/background modes.

### Localization/accessibility/layout

- No literal localization keys or unlocalized implementation strings in v1 flows.
- English complete; preserve/add existing locales consistently.
- VoiceOver labels/hints/order/traits cover selectors, attachments, errors, actions, destructive confirmation.
- Dynamic Type does not hide primary actions.
- Light/Dark use existing tokens.
- Check supported small/large iPhone, iPad, and macOS surfaces as environments allow.
- Fix concrete v1 regressions only; no visual redesign.

## Required tests

Cover at least:

- settings default save/load/update/remove;
- provider/default-model consistency;
- first-launch state and complete onboarding transition;
- failed validation preserves input/recovery;
- no dead Send without ready provider/model;
- required pre-v1 fixture migrations;
- malformed/missing data;
- draft/partial/attachment/conversation reload without duplicates;
- atomic update/error behavior where testable;
- credential create/update/delete/reference lifecycle;
- clear-data scope/confirmation;
- redaction;
- localization key presence;
- deterministic accessibility-facing state;
- appearance/provider lifecycle/navigation/generation regressions.

## Focused audit

Audit only settings/default coherence, onboarding dead ends, persistence compatibility/corruption/duplication, credential/privacy lifecycle, localization/accessibility/layout regressions introduced by M1–M4, and tests.

## Completion gate

A new user reaches working chat without dead ends; existing user data survives migration/relaunch; defaults stay coherent; credentials remain isolated; M1–M4 have zero P0/P1 findings.

Suggested commit:

~~~text
feat(app): complete onboarding settings and v1 data safety
~~~

---

# M5 — v1 Release Candidate

## Objective

Turn M1–M4 into the authoritative Omnia v1.0.0 RC: fix release blockers, update metadata, produce a green Apple CI build and unsigned IPA, and hand off a truthful physical-device checklist.

M5 is the only milestone permitting a broad **release-focused regression audit**. It is not permission for redesign or speculative refactor.

## Release preflight

- Confirm branch/remote sync and exclude user-owned files.
- Inventory actual test commands and Apple schemes.
- Reuse **.github/workflows/release.yml** unless a demonstrated defect needs a minimal fix.
- Use **App/Config/Shared.xcconfig** as current version source of truth.
- Inspect CHANGELOG/README/release conventions.
- Identify exact unsigned IPA path/name.
- Verify About version/build behavior.
- Do not create a parallel release pipeline.

## Release regression matrix

Run full automated tests and review:

- clean first launch/onboarding;
- provider add/edit/test/remove;
- default/active provider/model;
- model unavailable/capability states;
- text send/streaming;
- image/PDF/text attachment send/rejection;
- Stop/Retry/Continue/interruption;
- A → B → A during streaming;
- Providers/Settings/About navigation during streaming;
- partial/completed state after navigation/relaunch;
- rename/auto-title/search/grouping/delete;
- Markdown/links/code/Copy Code/long answers;
- offline/unauthorized/model/timeout/rate-limit/server errors;
- settings/clear-data/themes/localization/Dynamic Type/accessibility;
- migrations/no duplicates;
- credential/log redaction.

Fix every P0/P1. Run focused regression tests and repeat only the affected audit part.

## Version and release metadata

After RC behavior approval:

- set **MARKETING_VERSION = 1.0.0** in App/Config/Shared.xcconfig;
- increment/set **CURRENT_PROJECT_VERSION** per repository convention;
- ensure macOS/iOS consume the same source;
- About reads real bundle version/build;
- add a CHANGELOG.md v1.0.0 entry with M1–M4 changes, migrations, security notes, and known limitations;
- update README/status/features only where current text becomes false;
- add/update concise release notes/build instructions required by repository convention;
- create **Documentation/Development/V1_DEVICE_TEST_CHECKLIST.md**, or the established equivalent, with the checklist below and fields for device/OS/result/evidence;
- follow existing tag/release convention only after the version commit and authoritative build are ready;
- do not create/configure App Store distribution.

Metadata describes verified reality. Never claim device PASS before a human/device run.

## Commit/push and authoritative Apple build

After local gates:

1. review status, diff, and staged diff;
2. exclude unrelated/user-owned files;
3. commit RC fixes and release metadata coherently;
4. push tracked branch;
5. record pushed SHA;
6. trigger the existing authoritative Apple workflow through the unsigned credential-free path.

Suggested release commit:

~~~text
release: prepare Omnia 1.0.0
~~~

Required GitHub Actions gates:

- checkout exact pushed SHA;
- select/verify repository-defined Xcode;
- resolve packages;
- run standard package/root tests;
- build required Apple targets;
- archive iOS with signing disabled;
- package archived app as unsigned IPA;
- verify IPA exists/non-empty;
- upload GitHub Actions artifact.

Do not configure/modify certificates, profiles, Developer Team credentials, App Store credentials, TestFlight, App Store submission/distribution, or notarization as an iOS requirement. Optional existing signed branches remain untouched unless they break unsigned output. Never add secrets.

If CI fails:

1. capture exact error;
2. classify source/test/package/Xcode/project/archive/packaging/workflow/runner/external;
3. fix smallest in-scope cause;
4. run relevant local tests;
5. focused-audit the fix;
6. commit/push;
7. rerun the same workflow;
8. repeat until green or a genuine external blocker is proven.

Never suppress compiler/test errors, weaken gates, or fabricate output.

## Unsigned IPA verification

Report:

- workflow name and run URL/ID;
- source SHA;
- test/build/archive result;
- exact artifact and IPA name;
- artifact upload success;
- non-zero size;
- structure contains Payload/<app>.app;
- embedded version/build matches 1.0.0;
- no secret/private signing material;
- unsigned installation limitation stated plainly.

Signing the IPA is outside scope.

## Physical-device checklist

The handoff checklist must include:

### Environment

- device model and OS;
- app version/build;
- artifact run/SHA;
- clean install or upgrade;
- tested endpoint/model without credential.

### Install/launch

- externally sign/install using user’s chosen method;
- clean launch;
- upgrade data preservation;
- no crash/blank root;
- About version/build.

### Onboarding/providers/models

- no-provider Add Provider path;
- Add/Edit/Test Connection;
- invalid key/endpoint/model errors;
- active/default provider/model;
- per-conversation model persistence;
- unavailable-model behavior;
- provider deletion/credential cleanup.

### Chat/generation

- new chat/text send;
- thinking/streaming/completed;
- Stop;
- Retry/Continue;
- A → B → A during streaming;
- navigate Providers/Settings/About during streaming;
- lock/unlock and background/foreground;
- no duplicates/cross-conversation chunks;
- history after relaunch.

### Attachments

- one photo;
- multiple images;
- Files picker;
- PDF;
- text document;
- remove before send;
- unsupported type;
- size/count limit;
- unsupported model capability;
- model/provider change while staged;
- reload history and deletion cleanup.

### Conversation/Markdown/errors

- rename/auto-title;
- search/date groups/swipe/delete;
- headings/lists/quotes/links;
- inline/fenced code;
- horizontal scroll/Copy Code;
- long streaming Markdown;
- offline/unauthorized/model/timeout/rate-limit/server error where safe;
- recovery without duplicates.

### UI/accessibility/privacy

- small and large iPhone classes where available;
- iPad where available;
- Light/Dark;
- keyboard dismiss/draft preservation;
- Dynamic Type including accessibility size;
- VoiceOver primary flow;
- rotation/safe areas where supported;
- no clipped primary controls/overflow/literal localization keys;
- no credential/message/file content in diagnostics/logs.

Every line is marked **PASS**, **FAIL**, **BLOCKED**, or **NOT RUN** with evidence/notes. Every FAIL is triaged P0/P1/P2.

## M5 completion gate

M5 is complete when:

- M1–M4 criteria remain satisfied;
- all available automated tests pass;
- release audit has zero open P0/P1;
- version/metadata consistently say 1.0.0;
- changes are committed/pushed;
- authoritative Apple Actions run is green;
- exact unsigned IPA is produced/verified;
- device checklist exists for truthful execution;
- signing/App Store work was not introduced.

---

## 6. Explicitly Out of Scope for v1.0.0

- completion/expansion of .ai short-prompt framework;
- prompt library/marketplace;
- Omnia accounts/cloud sync/collaborative chats;
- voice/push notifications;
- plugin/tool/MCP ecosystem;
- built-in web search;
- image-generation UI;
- workspaces;
- analytics/telemetry;
- provider-specific branded UI;
- arbitrary background execution modes;
- Apple signing/certificates/provisioning;
- TestFlight/App Store Connect/App Store distribution.

If one appears necessary, first prove a required v1 criterion cannot be met through the current generic architecture. Otherwise defer it.

---

## 7. Final Definition of Done

- [ ] M1 model discovery/selection/defaults/per-conversation persistence work.
- [ ] M1 capability gating is truthful/generic.
- [ ] M1 Test Connection has safe actionable errors.
- [ ] M2 image/PDF/text attachment pipeline works end to end.
- [ ] M2 storage/persistence/limits/cleanup/privacy are tested.
- [ ] M3 rename/title/search/grouping/delete/new-chat are coherent.
- [ ] M3 Markdown/code/Copy Code work during/after streaming.
- [ ] M3 error recovery is readable and non-duplicating.
- [ ] M4 settings/defaults/onboarding have no dead end.
- [ ] M4 migrations protect existing data.
- [ ] M4 credentials stay secure and out of logs/files.
- [ ] Localization/accessibility/Dynamic Type/themes/layout have no P0/P1.
- [ ] Existing UI/generation/conversation isolation/provider lifecycle did not regress.
- [ ] Full deterministic tests pass.
- [ ] Release-focused audit has zero P0/P1.
- [ ] MARKETING_VERSION is 1.0.0 and metadata is consistent.
- [ ] CHANGELOG/README/About/release notes describe reality.
- [ ] Every milestone was committed/pushed before the next.
- [ ] Final source SHA is pushed/identified.
- [ ] Authoritative GitHub Actions Apple workflow is green.
- [ ] Verified unsigned IPA exists.
- [ ] Device checklist exists with no fabricated results.
- [ ] No signing/App Store scope or secret material was introduced.
- [ ] Short-prompt framework changes are post-v1 only.
- [ ] Working tree is clean apart from identified user-owned files.

---

## 8. Required Final Report

Return only after M5 completes or a genuine stop condition.

Report:

- M1–M5 implementation, architecture decisions, migrations, deferred post-v1 items;
- exact test commands/suites/count/failures and Apple-only unknowns;
- P0/P1/P2 per milestone and final approval;
- milestone commit hashes, release commit/tag if convention uses one, push/sync, excluded user files;
- version/build, metadata, workflow/run, SHA, Xcode build/archive;
- artifact/IPA name, size, structure/version verification, unsigned limitation;
- device-checklist path and only actually executed device results, otherwise “awaiting device execution.”

---

## 9. Final Instruction

Execute continuously:

~~~text
M1 → TEST → FOCUSED AUDIT → FIX P0/P1 → COMMIT/PUSH
 ↓
M2 → TEST → FOCUSED AUDIT → FIX P0/P1 → COMMIT/PUSH
 ↓
M3 → TEST → FOCUSED AUDIT → FIX P0/P1 → COMMIT/PUSH
 ↓
M4 → TEST → FOCUSED AUDIT → FIX P0/P1 → COMMIT/PUSH
 ↓
M5 → RELEASE AUDIT → FIX P0/P1 → VERSION 1.0.0
   → RELEASE METADATA → COMMIT/PUSH
   → AUTHORITATIVE GITHUB ACTIONS APPLE BUILD
   → FIX CI UNTIL GREEN
   → VERIFIED UNSIGNED IPA
   → DEVICE-TEST CHECKLIST
~~~

Do not ask after implementation whether to test.
Do not ask after tests whether to audit.
Do not ask after audit whether to commit.
Do not ask after commit whether to push/continue.
Do not reopen confirmed UI/generation/provider-lifecycle work without a demonstrated regression.
Do not let signing/App Store distribution block the unsigned v1.0.0 objective.

The final objective is a tested, pushed, GitHub-built, device-testable **Omnia v1.0.0 unsigned IPA**, with the short-prompt framework explicitly deferred to post-v1.


