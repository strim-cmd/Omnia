# Public Repository Release Readiness Report

Date: 2026-08-09
Repository: `github.com/strim-cmd/Omnia`
Branch: `develop`
Scope: publication readiness for the repository contents — the two-step plan
(step 1: working-tree content sanitization and verification; step 2: the
published-snapshot release via the documented export mechanism). This report
documents step 1 only; step 2 is out of scope here.

Status: **READY FOR STEP 2** — the working tree is sanitized, verified, and
self-consistent; the remaining required change (`.ai/` exclusion) is performed
by the export mechanism at publication time, not in this tree.

---

## Executive summary

The repository is ready for the step-2 export to public. Evidence:

- **No secrets and no private infrastructure references** anywhere in the
  tracked working tree or in Git history (verified below).
- **No dangling references to the private `.ai/` directory**: the only
  `.ai/` mentions left in public files are the intentional README note and the
  app-icon binary. Every previously-coupled public file (issue templates, code
  comments, doc links, design API docs, roadmaps, retrospectives) has been
  rewritten to descriptive references.
- **The full integrated branch is green**: 1057 tests across all six packages,
  0 failures, on the Linux build environment.
- **A real license file now exists** and the README declares the same MIT grant
  (the audit's M-1).
- **The README now carries build/run/test instructions** (the audit's M-2).

---

## 1. Reproducible release facts (v0.5.0)

- Release **v0.5.0** (2026-08-07) — "Beta v0.5 candidate", first distributable
  build (native macOS and iOS apps, streaming conversations, provider
  connections). Recorded in `CHANGELOG.md` `[0.5.0]`.
- Tags: `v0.5.0` and `v0.5.1` both point at commit `6c3d8b9` on `develop`
  (verified: `git rev-parse v0.5.0^{commit} v0.5.1^{commit} develop` → all
  `6c3d8b9`).
- `MARKETING_VERSION` = `0.5.0` in `App/Config/Shared.xcconfig` — the single
  source of truth the release workflow reads, so the packaged version never
  diverges from the tagged release version.
- Release pipeline: `.github/workflows/release.yml` (pinned Xcode 16.2) builds,
  archives, and packages unsigned macOS and iOS artifacts; workflow-configured
  secrets, not file secrets.

## 2. What changed in the working tree (step 1)

### 2.1 Private-infrastructure references removed from tracked files

All remaining references to the private dev/CI host were removed or
genericized. Verification scans (below) now return zero matches for:

- `taila-***` / `***.ts.net` / `desktop-***` / Funnel hostnames — none.
- `zen_banach` (private Docker container name) — `.gitignore` comment
  rewritten to "the Linux test container". The name still appears in the
  L-1 retrospectives and the OMNIROUTE/RFC process notes; those are owner
  discretion (audit L-1, R-4) and are unchanged.

### 2.2 `.ai/` coupling removed from public files

Every tracked public file that referenced the private `.ai/` directory was
rewritten (issue templates, `App/Config/Shared.xcconfig`, `App/Omnia*.swift`,
`App/OmniaiOS*.swift`, `Packages/**/*.swift`, `Documentation/Architecture/*`,
`Documentation/Design/**`, `Documentation/Product/**`, `Documentation/RFC/*`,
retrospectives, `README.md`, `.github/workflows/release.yml`). References were
replaced with descriptive text or removed when the target file does not exist
in the public tree (e.g., issue-template "Related Documents" lists). The
deliberate exception is the README note (required by the task) and the app-icon
binary.

### 2.3 README updated

- Project Status section rewritten to reflect the current state: the `v0.5.0`
  release, the UX audit / UI redesign / OmniRoute work, and the live green
  numbers (1057 tests; per-package counts).
- Build/run/test instructions added (audit M-2) — plain-Swift test runs on the
  Linux container and the Xcode project on Apple platforms.
- MIT license grant text added matching the new `LICENSE` file (audit M-1).

### 2.4 New files

- `LICENSE` — MIT, 2026, Omnia contributors (audit R-2).
- `Documentation/Development/PUBLIC_REPOSITORY_SECURITY_AUDIT.md` — the
  completed security audit (216 lines; status field updated 2026-08-09).
- This report.

### 2.5 Compile fixes applied (Linux build)

Two SwiftUI-view files did not compile on the Linux build environment:

- `Packages/OmniaPresentation/Sources/OmniaPresentation/DesignTokens.swift` —
  wrapped in `#if canImport(SwiftUI)` so the module builds without an Apple
  platform (the token system remains available to the Apple view layer).
- `Packages/OmniaPresentation/Sources/OmniaPresentation/ConversationScreenView.swift` —
  removed the stale `import OmniaTheme` (the tokens are in the same module).

Both are comment/doc-only or guard-only changes; the full suite still passes.

### 2.6 Local (uncommitted) test artifacts

`Tests/OmniaTests/Sources/UpdateResponseTests.swift` is an intentionally
uncommitted local test file (commit hygiene) and does not affect the public
snapshot.

---

## 3. Repository-wide verification (post-change)

All scans run against the tracked working tree (`.ai/` excluded by design).
Except where noted, output was empty.

| Check | Result |
| --- | --- |
| `ts.net` / `taila` / Funnel hostnames | 0 matches |
| Private IPs (any IPv4 literal) | 0 matches |
| Credentials: `sk-*`, `ghp_*`, `github_pat_*`, `AKIA`, `AIza`, `BEGIN * PRIVATE` | 0 matches |
| Personal paths: `C:\`, `/Users/`, `/home/`, `//c/`, `MSYS_NO_PATHCONV` | 0 matches (after `.gitignore` fix) |
| Internal-only URLs | 0 matches (only shields.io badges + app-icon binary) |
| `.ai/` references in public files | 2 — the README note (intentional) and the app-icon binary |

Test suite on the Linux build environment: **1057 tests, 0 failures**
(OmniaFoundation 136, OmniaDomain 319, OmniaApplication 177, OmniaInfrastructure
187, OmniaPresentation 199, OmniaApp 39).

---

## 4. Open items (step 2 / owner decisions)

- **R-1 (required at publication): exclude `.ai/` from the exported public
  snapshot** — the export mechanism handles this; it is not a working-tree
  change. Do **not** commit the `.ai/` directory to the public repository.
- **L-3 / L-4 (owner decision, not changed):** pin `actions/checkout@v4` /
  `actions/upload-artifact@v4` to commit SHAs and move the CI build-keychain
  password (`-p "omniabuild"`) into a workflow secret. Safe as-is; hardening
  recommended before or after publication.
- **R-6 (recommended): migrate the Swift / Testing / UI standards** from
  `.ai/standards/` to `Documentation/Development/` so the descriptive
  references in `Documentation/Design/API/*` resolve to public documents (only
  `DocumentationStandard.md` is public today).
- **Pending platform-specific verification:** the end-to-end macOS launch
  (configure, create, send, stream, persist, relaunch) requires a real Apple
  machine (DES-013 §3.6). The SwiftUI view layer is isolated behind
  `canImport(SwiftUI)` and verified by review and Apple-platform builds only.
- **Do not commit:** `Documentation/Design/public.md` (gitignored chat export
  with the real Funnel endpoint) and the local `Tests/OmniaTests/Sources/UpdateResponseTests.swift`.

---

## Related Documents

- `PUBLIC_REPOSITORY_SECURITY_AUDIT.md` (this directory) — the security audit
  and its remediation-status table.
- `CHANGELOG.md` — `[0.5.0]` release record.
- `.github/workflows/release.yml` — the reproducible release pipeline.
- `App/Config/Shared.xcconfig` — single source of truth for `MARKETING_VERSION`.
- `README.md` — Project Status, Build/run/test, License.
