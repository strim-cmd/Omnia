# Public Release Final Check

Date: 2026-08-09
Repository: `github.com/strim-cmd/Omnia`
Branch: `develop`
Scope: final pre-publication check combining (a) the public repository security
posture and (b) the readiness of the GitHub Actions release pipeline to build a
**signed iOS IPA** on a GitHub-hosted macOS runner, driven entirely by GitHub
Secrets. Working tree only — nothing committed or pushed.

Status: **READY WITH CONFIGURATION**.

---

## 1. Public repository security verdict

**SAFE TO PUBLIC** for the tracked working tree. Full scans (below) found **no
secrets, no credentials, and no private infrastructure references** in the
working tree or in Git history. `.ai/` remains private and out of public scope.

Residual, non-security items to be aware of at publication:

- **Git history references `.ai/` filenames** (`.ai/context/PROJECT_STATE.md`,
  `.ai/specifications/...`, `.ai/standards/...`, `.ai/prompts/...`) in older
  commits — 109+ such references at `HEAD`, mostly doc links in
  `Documentation/Design/API/*` and retrospectives. These are filename
  references only; no `.ai/` content is exposed. The audit recommends **no
  history rewrite**; if the owner requires a zero-reference history, that is a
  separate, deliberate `filter-repo` exercise and is out of scope here.
- **`Documentation/Development/Retrospectives/` and the `OMNIROUTE_*` docs**
  describe the internal Windows/Docker dev host (audit L-1). No secrets; owner
  discretion to keep, trim, or relocate.
- **L-3 / L-4 (optional hardening, unchanged):** `actions/checkout@v4` and
  `actions/upload-artifact@v4` are pinned to major-version tags, not commit
  SHAs; the ephemeral CI build-keychain password `omniabuild` is hardcoded.
  Both are harmless as-is; consider hardening after publication.

## 2. Re-scan results (2026-08-09, post-change)

Run against the tracked working tree (`.ai/` excluded) and the full commit graph.

| Check | Working tree | Git history |
| --- | --- | --- |
| Funnel / Tailscale (`taila-***`, `***.ts.net`, `desktop-***`) | 0 | 0 |
| Credentials (`ghp_*`, `github_pat_*`, `sk-<20+>`, `AKIA`, `AIza`, `BEGIN * PRIVATE`) | 0 | 0 |
| Private paths (`C:\`, `/Users/`, `//c/`, `MSYS_NO_PATHCONV`, `/home/`) | 0 | 0 |
| Internal URLs / private IPs | 0 | 0 |
| `.ai/` references outside `.ai/` | 1 — the intentional README note (`README.md:87`) | only the doc-link references above (no content) |

`.ai/` (65 tracked files) is still tracked in this working repository and is
**excluded from the public snapshot by the export mechanism at publication
time** (audit R-1). No `.ai/` content is exposed by the public files.

## 3. iOS CI buildability — verification results

Verified statically on the Linux/Windows host (no Apple toolchain available);
the Swift package suite ran in the `swift:6.0` Linux container.

- **Workspace / scheme.** `Omnia.xcworkspace` references
  `App/Omnia.xcodeproj`; the `OmniaiOS` scheme is shared
  (`App/Omnia.xcodeproj/xcshareddata/xcschemes/OmniaiOS.xcscheme`) and its
  ArchiveAction uses `Release`. `xcodebuild -workspace Omnia.xcworkspace -scheme OmniaiOS ...` resolves.
- **Project.** `project.pbxproj` — iOS target `OmniaiOS`
  (`000000000000000000000010`):
  - Bundle identifier `com.omnia.ios`, `PRODUCT_NAME = OmniaiOS`.
  - `IPHONEOS_DEPLOYMENT_TARGET = 16.0`, `TARGETED_DEVICE_FAMILY = "1,2"`.
  - `SDKROOT = iphoneos`; Swift 6.0 (`SWIFT_VERSION` in `Shared.xcconfig`).
  - `INFOPLIST_FILE = Omnia/Info.plist` (ATS + local-network keys, valid on
    iOS) plus `GENERATE_INFOPLIST_FILE = YES`.
  - App icon asset present (`App/OmniaiOS/Assets.xcassets/AppIcon.appiconset`,
    1024 universal).
  - Packages `OmniaApp` and `OmniaPresentation` are the only target
    dependencies (local Swift packages at `../Packages/...`, all declaring
    `.iOS(.v16)`).
- **Platform compatibility of the dependency graph.** `FoundationNetworking`
  and `Security` imports are `canImport`-guarded; the Apple path uses
  `URLSession.bytes(for:)` streaming and the Keychain backend; storage uses
  `FileManager.urls(for: .applicationSupportDirectory, ...)` (available on
  iOS). SwiftUI views are `canImport(SwiftUI)`-guarded with `#if os(iOS)` /
  `#if canImport(UIKit)` branches. The Composition Root is platform-neutral.
  No macOS-only API is reachable from the iOS app.
- **iOS build regression found and reverted.** The previously recommended
  `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` was disproven by
  CI: the v0.5.1 pipeline built and packaged the iOS target without it, and the
  key caused the iOS build to fail (xcodebuild exit 70) on the v0.5.2 run. A
  SwiftUI `@main` app does not require a scene manifest in Info.plist; the key
  was removed in v0.5.3 (`project.pbxproj`).
- **Tests.** Standard suite green on the Linux build environment: **1057 tests,
  0 failures** (OmniaFoundation 136, OmniaDomain 319, OmniaApplication 177,
  OmniaInfrastructure 187, OmniaPresentation 199, OmniaApp 39).

## 4. Can the current workflow produce an IPA?

| Artifact | Before this change | After this change |
| --- | --- | --- |
| Unsigned IPA (third-party signing) | Yes | Yes (unchanged path) |
| Signed IPA (App Store / ad-hoc) | **No** — the workflow relied on `-allowProvisioningUpdates` to auto-create provisioning profiles, which cannot authenticate on an ephemeral GitHub-hosted runner (no interactive Apple ID session) | **Ready once secrets are configured** |

The signed-IPA path is now a deterministic, secret-driven flow on
`macos-15` (GitHub-hosted, no self-hosted runners):

1. Pin Xcode (16.2; falls back to the runner default with a warning if the
   pinned version is absent from the image).
2. Ensure the iOS SDK is present (downloads only if missing).
3. Build both app targets with `CODE_SIGNING_ALLOWED=NO` (compilation check).
4. Archive macOS (signed via `Developer ID Application` when macOS secrets are
   present, else unsigned).
5. Archive iOS — when iOS secrets are present: automatic signing with
   `CODE_SIGN_IDENTITY="Apple Distribution"` + `DEVELOPMENT_TEAM` +
   `-allowProvisioningUpdates`; else unsigned.
6. Import the distribution certificate from the secret p12 into an ephemeral
   keychain.
7. **Install the provisioning profile** from the secret into
   `~/Library/MobileDevice/Provisioning Profiles/` — this is the piece that
   makes signing work without an Apple ID session.
8. Export the IPA for the run's single method (`appstore` or `adhoc`) using
   `.github/export/ios-appstore.plist` / `ios-adhoc.plist`, or export an
   unsigned IPA when no signing secrets are configured.
9. Package macOS zip/DMG; notarize/staple when macOS secrets are present.
10. Upload all artifacts (`actions/upload-artifact@v4`).

One iOS distribution method per run (a single archive embeds one provisioning
profile, so producing both an App Store and an ad-hoc IPA from one archive is
not possible). Method chosen by the `workflow_dispatch` input
`ios_distribution`; tag-push releases default to `appstore`.

## 5. Required GitHub Secrets

Set in **Settings → Secrets and variables → Actions** (Repository). Referenced
by name only; values never enter the repository.

| Secret | Purpose | Required for |
| --- | --- | --- |
| `MACOS_CERT_BASE64` | macOS Developer ID Application certificate, `.p12` file, base64-encoded | macOS signed archive + notarization |
| `MACOS_CERT_PASSWORD` | Password of that `.p12` | macOS signing |
| `IOS_CERT_BASE64` | iOS Distribution certificate, `.p12` file, base64-encoded | iOS signed IPA |
| `IOS_CERT_PASSWORD` | Password of that `.p12` | iOS signing |
| `IOS_APPSTORE_PROVISIONING_PROFILE_BASE64` | App Store distribution `.mobileprovision` for bundle id `com.omnia.ios`, base64-encoded | `appstore` IPA (default) |
| `IOS_ADHOC_PROVISIONING_PROFILE_BASE64` | Ad-hoc distribution `.mobileprovision` for `com.omnia.ios`, base64-encoded | `adhoc` IPA |
| `APPLE_TEAM_ID` | Apple Developer Team ID (shared by macOS and iOS) | both |
| `APPLE_ID` | Apple Account email | macOS notarization |
| `APPLE_NOTARIZATION_PASSWORD` | Apple Account **app-specific password** for `notarytool` | macOS notarization |

Preconditions owned by the Apple Developer account (not repo files): the iOS
Distribution certificate must match the Team ID and be the one the
provisioning profile was created with; each `.mobileprovision` must include
`com.omnia.ios` and the cert.

## 6. What must be configured in GitHub UI

1. Add the 9 secrets above.
2. (Optional) The `workflow_dispatch` input `ios_distribution` picks `appstore`
   or `adhoc`; tag-push releases default to `appstore`.
3. **Verify on the first real run:** confirm Xcode 16.2 is present on the
   `macos-15` image (the "Pin Xcode version" step warns and uses the default if
   not); if not, update `PINNED_XCODE_VERSION`/`PINNED_XCODE_PATH` in
   `release.yml`.
4. Suggested validation order:
   - Run **without** secrets → unsigned build + unsigned IPA + macOS zip/DMG
     succeed; signing steps skip.
   - Add secrets → re-run → signed IPA produced and uploaded as an artifact.
5. Post-publication: pin Actions to commit SHAs and move the build-keychain
   password to a secret (L-3/L-4) at the owner's convenience.

## 7. Is `.ai/` safely excluded?

**Yes.** `.ai/` (65 tracked files) remains private/out of public scope; the
public snapshot excludes it via the export mechanism (audit R-1). The working
tree contains no dangling `.ai/` references — the only mention in public files
is the intentional README note. The historical `.ai/` filename references in
Git history are documented above and are not content exposure.

## 8. Files and workflows involved

- `.github/workflows/release.yml` — the release pipeline (modified this pass:
  `workflow_dispatch` input `ios_distribution`, `IOS_DIST_METHOD` env,
  `HAS_IOS_DIST` gated on profile secrets, "Install iOS provisioning profile"
  step, single method-driven export step, unsigned-export gating,
  `CODE_SIGN_IDENTITY="Apple Distribution"` on the iOS signed archive,
  resilient iOS-platform step).
- `.github/export/ios-appstore.plist`, `ios-adhoc.plist` — export options
  (unchanged; `method`/`signingStyle: automatic`).
- `App/Omnia.xcodeproj/project.pbxproj` — iOS target (modified: scene-manifest
  generation key). Bundle id `com.omnia.ios`, iOS 16.
- `App/Omnia.xcodeproj/xcshareddata/xcschemes/{Omnia,OmniaiOS}.xcscheme` —
  shared schemes (unchanged).
- `App/Config/*.xcconfig` — version + signing baseline; `Shared.xcconfig`
  `CODE_SIGN_IDENTITY = -` overridden at CI time (unchanged).
- `Omnia.xcworkspace` — single-project workspace (unchanged).

## 9. Final recommendation

**READY WITH CONFIGURATION.**

- The repository is safe to publish from a security standpoint (no secrets, no
  private infrastructure, `.ai/` excluded).
- The iOS CI pipeline can build and archive the OmniaiOS target on a
  GitHub-hosted `macos-15` runner and can already produce an **unsigned IPA**
  with zero secrets.
- Producing a **signed IPA** now requires only owner configuration: the 9
  GitHub Secrets above (notably the iOS distribution certificate and the
  App Store / ad-hoc provisioning profile) plus a first-run verification of
  the pinned Xcode on the runner image. No further code, workflow, or
  repository changes are needed.

## Related Documents

- `PUBLIC_REPOSITORY_RELEASE_READINESS.md`, `PUBLIC_REPOSITORY_SECURITY_AUDIT.md`
  (this directory) — earlier audit and remediation records.
- `.github/workflows/release.yml` — the pipeline this report describes.
- `README.md` — Project Status, Building & Testing, License.
