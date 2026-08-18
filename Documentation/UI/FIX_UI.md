Continue Omnia to the next release-ready state autonomously.

IMPORTANT:
- Do NOT start another endless read-only audit.
- Do NOT stop after each item asking for confirmation.
- Do NOT redo already completed UI work unless verification finds a real regression.
- Work through the entire remaining scope in this prompt.
- Reuse the existing architecture, documentation, contracts, tests and CI.
- Make reasonable implementation decisions autonomously.
- Only stop if there is a genuine blocker that cannot be solved from the repository.
- Signing is explicitly OUT OF SCOPE. Unsigned IPA is the required release artifact.

==================================================
CURRENT STATE
==================================================

The major Presentation/UI redesign and the latest user-observed UI fixes are already implemented.

The following 7 user issues are considered DONE and should only be touched if regression is found:

1. Side menu is available beyond only the main conversation screen.
2. Providers and Settings are distinct destinations.
3. Provider Add/Edit uses one unified provider form.
4. Provider "+" is hidden while the provider form is open.
5. provider_unavailable is driven by real provider lifecycle/readiness state.
6. Message composer is adaptive instead of permanently tall.
7. Dark Mode actually switches light/dark and persists through appearance.darkMode.

Current verification previously reached:
- all available Swift package tests green;
- 1054 tests / 0 failures;
- git diff --check clean.

The repository already has a working GitHub Actions macOS/iOS build pipeline.
A previous CI run successfully produced:
- macOS app
- iOS app
- unsigned iOS archive
- omnia-ios-unsigned.ipa
- macOS DMG/ZIP artifacts

Apple signing is intentionally skipped.

==================================================
PRIMARY GOAL
==================================================

Bring the repository from the current UI-complete state to a coherent
RELEASE-READY / UNSIGNED-IPA-READY state.

The final state must:
- compile on the authoritative macOS/Xcode CI;
- pass the full test suite;
- produce the unsigned IPA;
- have coherent provider routing and provider lifecycle behavior;
- have no known dead Presentation code or stale documentation contradicting reality;
- have release metadata/documentation in a usable state;
- preserve the established architecture and dependency direction.

==================================================
PHASE 1 — VERIFY CURRENT WORKING TREE
==================================================

First inspect:

- git status
- current branch
- HEAD
- origin/main
- recent commits
- current diff
- package structure
- existing CI workflows
- release/version configuration
- existing project documentation

Determine which changes are already committed and which are still uncommitted.

Do NOT revert valid existing work.

Do NOT modify unrelated files.

Do NOT commit anything yet.

==================================================
PHASE 2 — PROVIDER ARCHITECTURE / OMNIROUTE INTEGRATION
==================================================

Complete the remaining provider integration scope described by the existing
architecture/documentation.

Goal:

Omnia must support per-provider model routing cleanly.

Inspect the existing provider model, ProviderConnectionService,
ProviderLifecycleService, configuration repository, conversation/provider
selection flow and any existing OmniRoute-related code/documentation.

Implement only what the existing architecture requires.

Requirements:

- provider configuration must remain provider-specific;
- model selection must be associated with the selected provider;
- endpoint configuration must remain provider-specific;
- provider readiness must not be inferred incorrectly from configuration existence;
- connection lifecycle must remain explicit;
- do not introduce a second provider abstraction;
- do not hardcode provider names where the existing model supports configuration;
- preserve credential references and existing credential storage boundaries;
- preserve existing error/retry behavior;
- preserve localization.

If OmniRoute integration already exists partially, finish the missing wiring
rather than replacing it.

If the repository intentionally keeps OmniRoute integration behind an existing
boundary, respect that boundary.

Do not introduce unnecessary networking infrastructure into Presentation.

Add/update tests for:
- provider selection;
- provider -> model routing;
- endpoint/model persistence;
- provider lifecycle;
- unavailable/ready transitions;
- unknown provider rejection;
- credential-reference preservation.

==================================================
PHASE 3 — UX AUDIT #154 REMAINING FINDINGS
==================================================

Review the existing UX audit #154 and current implementation.

Resolve only findings that are still genuinely present.

Known historical findings include:

- assistant/user bubble contrast;
- retry/continue behavior;
- endpoint editing;
- unified provider editing;
- compact composer;
- provider availability;
- navigation chrome.

Many of these have already been fixed.

Therefore:
- verify current source before changing anything;
- do not recreate already-fixed code;
- close only remaining real findings.

For bubble contrast:
- use existing OmniaTheme/design tokens;
- do not hardcode colors;
- ensure assistant/user/system/error surfaces remain visually distinguishable;
- preserve accessibility/readability.

For retry/continue:
- verify interrupted/partial assistant messages;
- ensure retry/continue actions are only shown when semantically valid;
- ensure partial streaming content does not receive invalid actions;
- preserve existing resume/retry implementation.

For endpoint editing:
- ensure the unified provider form is the canonical path;
- no dead Edit Endpoint/Edit Model UI should remain;
- no duplicate form implementations.

==================================================
PHASE 4 — PRESENTATION CLEANUP
==================================================

Search the Presentation package for remaining dead/orphaned code.

Look for:

- unused views;
- unused components;
- stale localization keys;
- stale comments describing removed behavior;
- duplicate helpers;
- obsolete compatibility code;
- dead state;
- unreachable navigation helpers;
- unused imports;
- obsolete documentation references;
- hardcoded colors where design tokens already exist;
- hardcoded dimensions that contradict the current responsive design.

Do NOT delete something merely because it is not referenced locally if it is
clearly an intentional public design-system component or architectural API.

Before deleting anything:
- verify production/test references;
- verify documentation references;
- verify package/API usage.

Do not perform speculative cleanup outside the current release scope.

==================================================
PHASE 5 — COMPOSER / DESIGN TOKEN FINALIZATION
==================================================

Finalize the compact/adaptive composer according to the existing design spec.

Requirements:

- empty composer must remain compact;
- multiline input may grow naturally;
- no unnecessarily large fixed vertical area;
- send button remains accessible;
- attachment/action controls remain accessible;
- keyboard behavior must remain valid;
- accessibility hit targets remain >= 44pt where required;
- use existing design tokens;
- avoid arbitrary new magic numbers.

Verify the resulting implementation against the existing UI documentation/design
spec rather than inventing a new visual language.

==================================================
PHASE 6 — NAVIGATION / TOP BAR FINALIZATION
==================================================

Verify all top-level routes:

- conversation;
- conversation list;
- providers;
- settings;
- about;
- provider add/edit;
- any other existing top-level destination.

Requirements:

- no duplicate system/custom navigation chrome;
- side menu remains accessible where appropriate;
- back navigation remains functional;
- pushed screens must not display an unnecessary second top bar;
- navigation state remains centralized;
- do not introduce another NavigationStack architecture;
- drawer routes must remain deterministic.

Check both:
- source-level behavior;
- existing navigation tests.

==================================================
PHASE 7 — DARK/LIGHT MODE FINALIZATION
==================================================

Verify appearance behavior end-to-end.

Requirements:

- dark mode visibly changes the interface;
- light mode visibly changes the interface;
- preference persists through relaunch;
- existing appearance.darkMode configuration key remains the source of truth;
- no second theme persistence mechanism;
- no hardcoded dark-only surfaces that make light mode unusable;
- design tokens should be used instead of raw colors.

Do not regress the current default behavior.

==================================================
PHASE 8 — LOCALIZATION / ACCESSIBILITY
==================================================

Perform a targeted release pass.

Localization:
- all user-visible strings must use existing localization infrastructure;
- remove obsolete keys only when proven unused;
- add missing keys where required;
- do not silently leave English fallback text where localization exists.

Accessibility:
- interactive controls must have appropriate labels;
- hit targets should respect the established 44pt requirement;
- provider menus/buttons should be accessible;
- add/edit/delete actions should have meaningful accessibility labels;
- navigation controls should remain discoverable.

Do not redesign the accessibility architecture.

==================================================
PHASE 9 — RELEASE METADATA / DOCUMENTATION
==================================================

Bring release-facing documentation into agreement with the actual repository.

Inspect:

- CHANGELOG.md
- README.md
- LICENSE
- version/build configuration
- existing release documentation
- CI documentation
- architecture/product docs that contain stale implementation claims

Update only what is necessary for the current release.

Requirements:

- no documentation should claim functionality that no longer exists;
- no documentation should say Dark Mode is non-persistent if it is persistent;
- no documentation should describe separate endpoint/model editing if it was removed;
- no documentation should describe Providers as part of Settings if they are now separate;
- release version/build information must be coherent;
- changelog should describe the current release scope accurately.

Do NOT rewrite the entire documentation set unnecessarily.

If LICENSE already exists and is correct, leave it alone.

==================================================
PHASE 10 — GITHUB ACTIONS / CI DETERMINISM
==================================================

Inspect the existing GitHub Actions workflow responsible for Apple builds.

Goal:
make the unsigned release build deterministic and reproducible.

Verify:

- Xcode version is explicitly pinned or otherwise deterministic;
- Swift/package dependencies are deterministic;
- iOS target builds correctly;
- macOS target builds correctly;
- tests execute before packaging;
- archive/export steps are correct;
- unsigned IPA is produced;
- artifact names are stable;
- failure in tests prevents packaging;
- signing is NOT required;
- no signing secrets are required for the unsigned path.

Do not add Apple signing.

If the workflow has unnecessary nondeterministic behavior, fix it.

Do not replace a working CI pipeline with an unnecessarily complicated one.

==================================================
PHASE 11 — AUTHORITATIVE MACOS CI
==================================================

After all implementation work is complete, push the completed changes to
GitHub and run the existing authoritative macOS CI.

The Apple CI is the source of truth for:

- SwiftUI compilation;
- Apple SDK compatibility;
- iOS target compilation;
- macOS target compilation;
- runtime-facing compile issues that Linux cannot detect;
- archive/export;
- unsigned IPA generation.

Expected result:

- full test suite green;
- iOS build green;
- macOS build green;
- unsigned archive generated;
- unsigned IPA generated.

If CI fails:

1. inspect the actual failure;
2. fix the root cause;
3. rerun CI;
4. do not merely document the failure if it is realistically fixable.

Continue until CI is green or a genuine external blocker is reached.

==================================================
PHASE 12 — FINAL QUALITY GATE
==================================================

Before final commit, run all locally available checks:

- swift-parse on changed Swift files where available;
- full Swift package tests;
- OmniaPresentation tests;
- root tests;
- git diff --check;
- grep/search for obsolete symbols;
- localization key validation;
- package build verification;
- git status;
- git diff --stat.

Confirm:

- no accidental changes;
- no unrelated files;
- no generated junk;
- no audit documents accidentally committed;
- no signing secrets;
- no credentials;
- no hardcoded API keys;
- no changes outside intended scope.

==================================================
GIT / COMMIT POLICY
==================================================

Do NOT create a separate commit for every small fix.

After the entire scope is complete and verified:

1. create ONE coherent release-preparation commit for this scope;
2. push it to origin/main;
3. run the GitHub Actions release workflow;
4. if CI fails, fix and create a follow-up fix commit only when necessary;
5. rerun CI.

Do not commit:
- audit scratch files;
- temporary reports;
- credentials;
- build artifacts;
- local machine configuration.

==================================================
FINAL REPORT
==================================================

At the end provide one concise but complete report containing:

1. What was already complete and therefore left untouched.
2. What was implemented in this session.
3. Provider/OmniRoute status.
4. UX #154 status.
5. Presentation cleanup status.
6. Localization/accessibility status.
7. Documentation/release metadata status.
8. GitHub Actions status.
9. Test count and failures.
10. Final commit hash.
11. origin/main synchronization status.
12. Exact unsigned IPA artifact name/path if available.
13. Any remaining blockers.

IMPORTANT:
The project is considered successful when the unsigned IPA is produced by the
existing GitHub Actions pipeline.

Apple signing is explicitly NOT required and must not block completion.

Do not stop merely because signing is unavailable.