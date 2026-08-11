# Omnia — Autonomous Implementation Scope for OpenCode

## Objective

Move Omnia from the current completed Presentation/UI redesign and cleanup state to a **real buildable iOS application with IPA generation through GitHub Actions**.

OpenCode should execute this plan continuously. It should not repeatedly stop for low-value audits or ask what to do next after every phase.

---

## Current state

Already completed and pushed:

- Presentation/UI redesign and reference alignment.
- Conversation screen and conversation list cleanup.
- Providers / Settings cleanup.
- Active Provider overflow menu.
- Removal of duplicate system navigation chrome.
- Dark Mode persistence through the existing settings surface.
- About screen.
- Localization cleanup.
- Removal of audited dead/orphaned UI components and localization keys.
- ErrorBannerView cleanup.
- Conversation `resume` production path.
- Presentation tests currently pass.
- Recent UI commits are on `origin/main`.

Important constraint:

- The development environment may not have Xcode.
- Linux/Docker validation can verify Swift/package-level correctness but cannot prove iOS runtime/build behavior.
- **The authoritative iOS build and IPA generation must happen in GitHub Actions on macOS.**

The goal is no longer another broad UI audit.

---

# 1. Operating rules

### 1.1 Work continuously

Proceed from one phase to the next without asking for confirmation.

Stop and ask the user only when:

- a genuine product decision is ambiguous;
- Apple Developer credentials/signing information is required;
- a GitHub secret is required;
- a destructive migration is unavoidable;
- repository specifications conflict;
- continuing would risk data loss.

Otherwise continue autonomously.

### 1.2 No audit loops

Do not repeatedly audit already-verified Presentation code.

Only perform a new audit when:

- entering a new architectural phase;
- diagnosing a build/test failure;
- introducing a cross-layer contract;
- repository documentation explicitly requires it.

### 1.3 Source of truth

Before architectural changes, read:

1. `AI_CONSTITUTION.md`
2. `Documentation/Product/*`
3. `Documentation/Architecture/*`
4. `Documentation/Development/*`
5. package manifests
6. source/tests

Follow repository terminology and existing architectural decisions.

### 1.4 Preserve layer boundaries

Respect the existing direction:

`Presentation -> Application -> Domain`

and the repository's defined Infrastructure relationships.

Do not move persistence, networking, provider logic, or business rules into SwiftUI views just to simplify wiring.

### 1.5 No speculative dependencies

Do not add third-party dependencies without a concrete architectural reason.

Prefer existing packages and Apple/Foundation APIs.

### 1.6 No fake production implementations

Do not use hardcoded successful responses, disabled tests, empty production services, or fake providers merely to make CI green.

Mocks/stubs are allowed in tests.

### 1.7 Incremental commits

After each meaningful phase:

```bash
git status --short
git diff --check
```

Run the strongest available validation, then commit and push.

Never mix unrelated work into a phase commit.

### 1.8 Protect untracked audit documents

Do not accidentally commit:

```text
Documentation/Development/UI_PRE_COMMIT_INSPECTION.md
Documentation/Development/UI_REDESIGN_FINAL_AUDIT.md
```

unless explicitly required.

Before every commit inspect:

```bash
git status --short
git diff --stat
git diff --cached --stat
```

---

# 2. Phase 0 — Repository baseline

Inspect:

- current branch and remote;
- `HEAD` vs `origin/main`;
- package structure;
- Swift Package manifests;
- architecture documentation;
- current application entry point;
- whether an Xcode project/workspace already exists;
- platform declarations;
- package products and targets;
- test targets.

Run where available:

```bash
git status --short
git log --oneline -10
swift package dump-package
swift test
```

If local Swift is unavailable, use the existing Docker/Linux validation.

Do not perform another Presentation audit.

---

# 3. Phase 1 — Implementation/package architecture

Complete the implementation architecture already described by the repository.

Verify:

- target names;
- products;
- dependencies;
- public APIs;
- test targets;
- resource handling;
- platform declarations;
- Swift version;
- module boundaries.

Pay particular attention to the existing:

- `OmniaDomain`
- `OmniaApplication`
- `OmniaInfrastructure`
- `OmniaPresentation`

Do not introduce dependency cycles.

Completion condition:

- package graph is explicit;
- dependency direction is valid;
- package builds/tests on the available toolchain.

Suggested commit:

```text
feat(architecture): complete implementation package structure
```

---

# 4. Phase 2 — Application composition/root wiring

Create/complete a real composition root.

Wire:

- repositories;
- persistence;
- provider configuration;
- application services/use cases;
- Presentation dependencies.

The application entry point/root should remain thin.

Do not put business logic into `App` or `RootView`.

Completion condition:

> The application can be constructed through one coherent dependency graph.

---

# 5. Phase 3 — Persistence

Complete the persistence architecture already specified by the repository.

At minimum cover the functionality actually defined by the existing model:

- configuration;
- appearance/dark mode;
- provider configuration;
- conversations where specified;
- deterministic load/save;
- update/remove;
- error handling.

Use the repository's persistence abstraction.

Do not silently replace the architecture with unrelated `UserDefaults`/AppStorage if the repository already specifies a repository/file-based mechanism.

Add tests for:

- save;
- load;
- update;
- remove;
- missing values;
- malformed data;
- defaults.

---

# 6. Phase 4 — Provider system

Complete the provider flow:

```text
Provider model
    ↓
Provider configuration
    ↓
Repository
    ↓
Application/provider service
    ↓
Presentation
```

Implement/finish:

- provider configuration;
- endpoint/model configuration;
- active provider selection;
- persistence;
- validation;
- error mapping;
- application-level integration.

The existing Providers UI should be reused rather than redesigned.

Active provider must be real application state, not only a SwiftUI local state.

---

# 7. Phase 5 — Conversation/application flow

Complete the real conversation path:

```text
Conversation UI
    ↓
Application conversation service/use case
    ↓
Provider abstraction
    ↓
Infrastructure implementation
    ↓
Response/stream
    ↓
Application state
    ↓
Presentation
```

Required behavior where supported by the existing product specification:

- send;
- assistant response;
- streaming/loading;
- interruption;
- retry;
- errors;
- conversation persistence;
- conversation selection;
- new conversation;
- delete conversation.

Do not put networking/provider implementation directly in `ConversationScreenView`.

Streaming should use application-level contracts rather than SwiftUI hacks.

---

# 8. Phase 6 — Message/Markdown rendering

Preserve the already-verified Markdown behavior.

Verify:

- assistant Markdown;
- user plain text;
- message content model;
- typography/token usage;
- no dead rendering components.

Do not resurrect removed components merely because historical design documents mention their names.

---

# 9. Phase 7 — Error/loading/empty states

Standardize the existing flows for:

- provider unavailable;
- invalid configuration;
- network error;
- authentication error;
- interrupted stream;
- retry;
- loading;
- empty state.

Reuse `ErrorBannerView` and shared components.

Rules:

- no hardcoded colors;
- no duplicate error UI;
- use localization;
- preserve existing design tokens.

---

# 10. Phase 8 — iOS application target

Inspect the repository first.

If an Xcode project/workspace already exists, use it.

If not, create the smallest correct iOS project/workspace required to build the existing Swift architecture.

Configure only what is required:

- iOS deployment target;
- application entry point;
- package dependencies;
- source/resources;
- Info.plist;
- supported devices;
- required capabilities.

Do not add speculative capabilities.

Do not commit signing credentials.

---

# 11. Phase 9 — GitHub Actions iOS build

This is a mandatory phase.

Create/complete:

```text
.github/workflows/
```

The workflow must use a macOS GitHub-hosted runner.

High-level pipeline:

```text
Checkout
  ↓
Select Xcode
  ↓
Resolve dependencies
  ↓
Run package/unit tests
  ↓
Build iOS target
  ↓
Archive
  ↓
Export IPA
  ↓
Verify IPA
  ↓
Upload IPA artifact
```

Derive exact `xcodebuild` commands from the actual project/workspace and scheme.

Do not invent build arguments before inspecting the generated project configuration.

---

# 12. Phase 10 — Signing

Separate build verification from signing.

## First milestone

Prove that the application can:

- compile on macOS;
- archive;
- produce the intended build output.

Use the least privileged/no-signing approach supported by the actual project for the first CI milestone.

## Second milestone

Configure IPA export.

If real Apple signing is required, identify the exact missing inputs:

- Apple Developer Team ID;
- bundle identifier;
- signing certificate;
- provisioning profile;
- App Store Connect API key or equivalent signing mechanism.

Never invent credentials.

Never print secrets.

Never commit:

- certificates;
- private keys;
- provisioning profiles;
- API keys.

---

# 13. GitHub Actions secrets

If signing requires secrets, document their expected names without values.

Example naming:

```text
APPLE_TEAM_ID
APPLE_CERTIFICATE_BASE64
APPLE_CERTIFICATE_PASSWORD
APPLE_PROVISIONING_PROFILE_BASE64
KEYCHAIN_PASSWORD
```

Use the actual names selected by the implementation.

Secrets must only be consumed through GitHub Actions secret/environment mechanisms.

Never echo secrets into logs.

Never upload temporary signing material as artifacts.

---

# 14. CI quality gates

The workflow must fail when:

- package compilation fails;
- tests fail;
- iOS compilation fails;
- archive fails;
- export fails;
- expected IPA is missing.

After export:

- verify the IPA exists;
- print non-sensitive path information;
- print file size;
- upload the IPA as a GitHub Actions artifact.

---

# 15. Local vs GitHub validation

### Local/Linux/Docker

Use for:

- Swift parsing;
- package build;
- unit tests;
- static checks;
- dependency graph validation;
- `git diff --check`.

### GitHub/macOS

Use for:

- Xcode build;
- iOS compilation;
- archive;
- signing;
- IPA export;
- simulator/device verification where practical.

Never claim Linux validation proves iOS runtime behavior.

---

# 16. Testing priorities

Prioritize tests by actual value.

### Required

- Domain logic;
- Application use cases;
- repositories;
- persistence;
- provider configuration;
- conversation flow;
- error mapping.

### Useful

- critical navigation behavior;
- important Presentation behavior.

### Avoid

Do not create hundreds of cosmetic SwiftUI tests.

The Presentation suite already has substantial coverage. Expand it only for meaningful behavior.

---

# 17. Documentation

When implementation stabilizes, update only the documentation that describes actual behavior:

- architecture;
- package structure;
- build instructions;
- GitHub Actions;
- signing/export;
- current project state.

Documentation must describe reality.

Do not retain statements such as "never persisted" when persistence exists.

Do not describe removed components as active architecture.

---

# 18. Commit strategy

Prefer coherent commits such as:

```text
feat(architecture): complete implementation package structure
feat(app): wire application composition root
feat(storage): complete persistence layer
feat(provider): complete provider configuration flow
feat(conversation): complete application conversation flow
feat(ios): add iOS application target
ci(ios): add GitHub Actions build
ci(ios): add IPA export
docs(build): document iOS and IPA build process
```

Adapt messages to actual work.

After each phase:

```bash
git status --short
git diff --check
git log -1 --oneline
git push origin main
```

---

# 19. Failure handling

When something fails:

1. Capture the exact error.
2. Classify it:
   - source code;
   - package graph;
   - architecture;
   - Xcode configuration;
   - signing;
   - CI environment;
   - missing secret;
   - external service.
3. Fix the smallest correct layer.
4. Re-run validation.
5. Continue.

Do not rewrite unrelated working code to bypass CI.

Do not suppress errors just to make CI green.

---

# 20. Stop conditions

Stop and ask the user only when:

### Product decision is genuinely required

Two valid user-facing behaviors exist and repository documentation does not select one.

### Apple credentials are required

Build/archive succeeds but IPA export requires the user's Apple Developer credentials.

### GitHub secrets are required

CI is ready but a required secret is unavailable.

### Destructive migration is required

Existing user data could be lost and no migration policy exists.

Otherwise continue.

---

# 21. Definition of Done

The implementation is complete when:

- [ ] Architecture matches repository specifications.
- [ ] Package dependency graph is clean and acyclic.
- [ ] Application composition root is real.
- [ ] Persistence is implemented and tested.
- [ ] Provider flow is implemented and persisted.
- [ ] Conversation flow uses application/domain abstractions.
- [ ] Error/loading/retry paths work.
- [ ] Existing UI redesign remains intact.
- [ ] Known dead production components from the current backlog are removed.
- [ ] Unit/application tests pass.
- [ ] iOS target exists.
- [ ] GitHub Actions runs on macOS.
- [ ] GitHub Actions compiles the iOS application.
- [ ] Archive succeeds.
- [ ] IPA export succeeds, or the only blocker is documented Apple signing configuration.
- [ ] IPA is uploaded as a GitHub Actions artifact.
- [ ] Build/signing instructions are documented.
- [ ] No secrets are committed.
- [ ] Working tree is clean.
- [ ] Changes are pushed to `origin/main`.

---

# 22. Final instruction to OpenCode

Execute this document as a **continuous implementation plan**.

Do not repeatedly ask what to do next.

At the end of each phase:

1. validate;
2. commit;
3. push;
4. immediately continue to the next applicable phase.

Use repository documentation and actual source code as the primary authority.

Prefer the smallest correct implementation.

Avoid speculative refactors.

Do not reopen closed UI audits unless a real regression is discovered.

**The objective is not another audit report.**

**The objective is a real Omnia iOS application that GitHub Actions can build and export as an IPA.**
