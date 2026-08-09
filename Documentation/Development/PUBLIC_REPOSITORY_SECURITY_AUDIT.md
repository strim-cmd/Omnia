# Public Repository Security & Release Audit

Date: 2026-08-09
Repository: `github.com/strim-cmd/Omnia`
Commit: `6c3d8b9`
Branch: `develop`

Scope: read-only final audit. No code modified, no git history changed, no files
removed, nothing committed or pushed. `.ai/` is treated as PRIVATE and out of
scope for the public release.

---

## Executive Verdict: **SAFE WITH CHANGES**

The repository contains **no secrets and no private infrastructure references**
in the working tree or in Git history. The code, tests, CI, and documentation
are clean. However, the repository **cannot be made public as-is** because:

1. `.ai/` (65 tracked files — the internal AI engineering framework) must be
   excluded from the public repository per the stated scope.
2. The repository has **no LICENSE file** while `README.md` declares an MIT
   license.

Both are policy/content changes (not security fixes) and can be resolved without
touching Git history.

---

## Findings

### Critical
None.

### High

**H-1 — `.ai/` must remain private (currently tracked and referenced)**
- Files: `.ai/**` (65 tracked files)
- Description: The internal AI engineering framework — constitution, agent
  specifications, prompts, workflows, standards, orchestrator definitions,
  project state — is project-private material that must not be published.
- Consequence: `.ai/` is **not self-contained**. Public files reference it:
  - `.github/ISSUE_TEMPLATE/{architecture,bug,documentation,feature,refactoring}.md`
    (links to `.ai/prompts/...`, `.ai/standards/...`)
  - `App/Config/Shared.xcconfig:3` (comment: `.ai/prompts/workflows/release.md`)
  - `App/Omnia/OmniaApp.swift:37,93` and `App/OmniaiOS/OmniaiOSApp.swift:38,94`
    (comments: `.ai/standards/UI.md`)
  - `Documentation/Architecture/01_SYSTEM_OVERVIEW.md:29,506` (`.ai/AI_CONSTITUTION.md`)
  - Numerous `Documentation/Design/API/*` and `Documentation/Design/*_API.md`
    files (`.ai/standards/...` references)
- Severity rationale: not a credential leak, but it defeats the "private .ai/"
  requirement — both the content and the deep coupling would be exposed.
- Recommended: exclude `.ai/` from the public snapshot (see Remediation R-1).

**H-2 — Untracked chat log contains the real Tailscale Funnel URL (mitigated)**
- File: `Documentation/Design/public.md` (untracked, now gitignored)
- Description: The file is a chat export containing the live Funnel endpoint
  `https://desktop-********.tail******.ts.net` and internal conversation detail.
- Status: **mitigated** — added to `.gitignore` (commit `6c3d8b9`); verified
  `git check-ignore` returns it and it never appears in `git status` or in Git
  history. It must never be committed. If the Funnel endpoint is reachable
  without ACL, the service itself should be access-restricted independently of
  this audit.

### Medium

**M-1 — Missing LICENSE file**
- `README.md` shows an MIT badge and an "MIT License" section, but **no
  `LICENSE`/`LICENSE.md` file is tracked or present**.
- For a public repository this is a legal/readiness gap — the license grant is
  ambiguous.

**M-2 — README lacks build/run/test instructions**
- `README.md` covers overview, philosophy, features, providers, architecture,
  docs, status, and roadmap, but has **no "How to build / How to run / How to
  test"** section. The release workflow and the platforms are implied, never
  documented for a first-time contributor.
- `README.md` also references a build-on-Linux-in-Docker process that only
  exists in internal retrospectives — a public user cannot build from README.

### Low

**L-1 — Internal development-infrastructure details in tracked docs**
- Files:
  - `Documentation/Development/Retrospectives/INFRASTRUCTURE_SPRINT_1_RETROSPECTIVE.md`
    (Windows dev host, no local Swift toolchain, `MSYS_NO_PATHCONV=1`, Docker
    `swift:6.0`, container name `zen_banach`)
  - `Documentation/Development/OMNIROUTE_INTEGRATION_FINAL_REVIEW.md`,
    `OMNIROUTE_INTEGRATION_STEP1.md`, `OMNIROUTE_INTEGRATION_STEP3.md`
    (Linux suite runs in the `zen_banach` container)
  - `Documentation/RFC/RFC-001_VALIDATION_SUITE_AUTOMATION.md`
- Content: internal process notes. No credentials, no reachable endpoints, no
  personal data beyond the project host. Owner's decision whether to keep,
  trim, or relocate; harmless from a security standpoint.

**L-2 — Author identity in Git history**
- Commits are authored as `michael.burobin@yandex.ru` (personal email) and a
  GitHub `noreply` account (`strim-cmd`). Normal for public repos; the owner
  should be comfortable with the personal email being visible.

**L-3 — Third-party Actions pinned to major-version tags, not commit SHAs**
- `.github/workflows/release.yml`: `actions/checkout@v4`,
  `actions/upload-artifact@v4`. Recommended: pin to full commit SHAs.

**L-4 — Hardcoded ephemeral build-keychain password**
- `.github/workflows/release.yml` creates a CI keychain with `-p "omniabuild"`.
  Transient runner-local value; harmless, but could be moved to a CI secret.

### Files affected
- `.ai/**` (65 files) — private, out of scope (H-1)
- `Documentation/Design/public.md` — untracked, gitignored (H-2, resolved)
- `README.md` — missing LICENSE link + build/run instructions (M-1, M-2)
- `Documentation/Development/Retrospectives/INFRASTRUCTURE_SPRINT_1_RETROSPECTIVE.md`
  (L-1)
- `Documentation/Development/OMNIROUTE_INTEGRATION_{FINAL_REVIEW,STEP1,STEP3}.md` (L-1)
- `Documentation/RFC/RFC-001_VALIDATION_SUITE_AUTOMATION.md` (L-1)
- `.github/ISSUE_TEMPLATE/*.md`, `App/Config/Shared.xcconfig`,
  `App/Omnia/OmniaApp.swift`, `App/OmniaiOS/OmniaiOSApp.swift`,
  `Documentation/Architecture/01_SYSTEM_OVERVIEW.md`, `Documentation/Design/API/*`
  — contain `.ai/` references (H-1)

---

## Git-history findings

- **No secrets have ever been committed.** `git grep <pattern> $(git
  rev-list --all)` across the full commit graph returned zero matches for
  `***.ts.net`, `taila-***`, `sk-<20+ chars>`, `ghp_*`, `github_pat_*`,
  `AKIA`, or `BEGIN ... PRIVATE` keys.
- **The Funnel URL never appeared in history** — only in the untracked
  `public.md`.
- `.scratch/` (Docker test workspace) was tracked historically and removed from
  tracking in `f38db99`; now gitignored. Its historical content is code and
  tests only.
- Temporary source copies `tmp_ConversationScreenView.swift` and
  `update_ConversationScreenView.swift` were tracked (introduced `f3c12a8`,
  removed `6c3d8b9`). Hygiene-only; no sensitive content.
- No `.env`, `*.p12`, `*.pem`, `*.key`, `*.jks`, `*.mobileprovision`,
  `credentials.*`, or `config.json` have ever been tracked.
- Current-tree exposure vs historical exposure: both **clean** — the only
  sensitive artifact is untracked and now gitignored.

---

## Recommended remediation

**R-1 (required) — Exclude `.ai/` from the public repository.**
Options, in order of preference:
1. Remove `.ai/` from tracking (`git rm -r --cached .ai`), add `.ai/` to
   `.gitignore`, and purge the tracked references listed in H-1 (issue
   templates, doc links, code-comment mentions) so the public tree contains no
   dangling references. (History untouched.)
2. If `.ai/` must remain in the repository, mirror it into a private
   submodule/repository and reference it from a private-only path.
3. Do **not** publish `.ai/` content or its coupling in the public tree.

**R-2 (required) — Add a `LICENSE` file** matching the declared MIT license and
link it from `README.md`.

**R-3 (recommended) — Add build/run/test instructions to `README.md`** so a
public reader can build and run the app without internal context.

**R-4 (optional) — Review the L-1 docs** (internal dev-host details) and keep,
trim, or relocate them at the owner's discretion.

**R-5 (optional hardening) —** Pin Actions to commit SHAs (L-3); move the
build-keychain password to a CI secret (L-4).

---

## Files/directories that should remain private

- `.ai/` — the entire directory (internal AI engineering framework: agents,
  prompts, workflows, standards, orchestrator, project state)
- `Documentation/Design/public.md` — chat export with the real Funnel endpoint
  (keep gitignored; do not commit)
- (owner's discretion) `Documentation/Development/Retrospectives/` and the
  `OMNIROUTE_INTEGRATION_*` docs that describe the Windows/Docker development
  host

## Files/directories considered safe to publish

- `Packages/` — OmniaFoundation, OmniaDomain, OmniaInfrastructure, OmniaApplication,
  OmniaPresentation, OmniaApp (source + tests)
- `App/` — Xcode project, `Config/*.xcconfig` (ad-hoc signing only, no secrets),
  `Info.plist` (ATS local-networking only), entitlements
- `.github/workflows/release.yml`, `.github/export/*.plist` — no secrets,
  `contents: read`, no PR trigger
- `Package.swift`, `Omnia.xcworkspace`
- `README.md`, `SECURITY.md`, `SUPPORT.md`, `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `CHANGELOG.md` (after M-1/M-2)
- `Documentation/Architecture/`, `Documentation/Design/API/`,
  `Documentation/Design/*_API.md`, `Documentation/Product/` — after the R-4
  review for L-1 content
- `Scripts/`, `Sources/`, `Tests/`, `Tools/` (empty placeholder dirs)

## `.ai/` verdict

**Yes — `.ai/` should remain private** and is out of scope for the public
release. It must be excluded (R-1) before the repository is made public.

---

## Remediation status (2026-08-09)

All remediation has been applied to the working tree; nothing has been committed
or pushed. Verification commands re-run after the changes:

| Finding | Status | Evidence |
| --- | --- | --- |
| H-1 — `.ai/` coupling exposed | **Resolved** | `git grep "\.ai/"` now matches only the README note (intentional, required by task) and the app-icon binary. Issue templates no longer reference `.ai/`; code comments and doc links rewritten to descriptive references. |
| H-2 — Funnel URL in `public.md` | Mitigated (unchanged) | File untracked and gitignored; never in history. |
| M-1 — Missing LICENSE | **Resolved** | `LICENSE` (MIT, 2026, Omnia contributors) added at repo root; README declares the same grant. |
| M-2 — No build/run/test instructions | **Resolved** | `README.md` gains the "Build, run, and test" section. |
| L-1 — Internal dev-host details | Partially resolved | `zen_banach` reference removed from `.gitignore` comment; the OMNIROUTE/RFC/L-1 process notes remain by owner discretion (see note). |
| L-3/L-4 — Actions pinning / keychain password | **Not changed** | Deliberate: release pipeline is out of scope for this remediation pass (owner decision). |

Verification scans re-run across the tracked tree: `ts.net`, Funnel hostnames,
private IPs, credential patterns (`sk-*`, `ghp_*`, `github_pat_*`, `AKIA`,
`AIza`, `BEGIN * PRIVATE`), personal paths, and internal-only URLs all return
zero matches outside `.ai/` (excluded) and the allowed README/app-icon mentions.

Note: `Documentation/Development/DocumentationStandard.md` is the only standard
made public so far; the Swift/Testing/UI standards remain inside `.ai/standards/`
and are still referenced descriptively from `Documentation/Design/API/*`. A
follow-up may migrate them to `Documentation/Development/` (recommendation R-6 in
the release-readiness report).

---

## Final Recommendation

**Can the repository be made public after the listed changes?** Yes.

No real secrets, credentials, or private infrastructure references exist in the
working tree or in Git history. The required changes are content/policy only and
do not require rewriting history:

1. Exclude `.ai/` and its tracked references (R-1).
2. Add a `LICENSE` file (R-2).
3. (Recommended) Add build/run/test instructions to the README (R-3).

After R-1 and R-2, the repository is **SAFE TO PUBLIC**.
