# Omnia 1.0.0 Release Notes

Release date: 2026-08-14
Version/build source: `App/Config/Shared.xcconfig`
Version: `1.0.0`
Build: `1`

## Highlights

- Provider-scoped model discovery, cached catalogs, coherent defaults, explicit
  per-conversation selection, capability gating, and real connection testing.
- Capability-aware image, PDF, and plain-text attachments with durable metadata,
  validation, request routing, and cleanup.
- Persistent titles, timestamps, rename precedence, search/date grouping, safe
  Markdown/code rendering, copy actions, and actionable recovery errors.
- First-launch Add Provider guidance, durable unsent drafts, malformed-record
  isolation, and confirmed Clear Data for chats, attachments, settings, provider
  metadata, and app-owned secure credentials.
- Existing generation isolation remains intact across chat changes, navigation,
  stop/retry/continue, and background/foreground transitions.

## Persistence and Security

Pre-v1 serialized conversations, providers, and workspaces remain readable with
explicit defaults for newer fields. Individually malformed records are isolated
without silently deleting the rest. API keys stay in platform secure credential
storage; persisted provider/configuration records contain only safe metadata and
opaque credential references. Clear Data purges the complete Omnia credential
namespace so an unreachable or corrupted reference cannot retain an orphaned
secret.

## Build and Test

Run the deterministic Swift package gates:

```bash
swift test
for package in OmniaFoundation OmniaDomain OmniaApplication OmniaInfrastructure OmniaPresentation OmniaApp; do
  (cd "Packages/$package" && swift test)
done
```

Run Apple builds from the workspace:

```bash
xcodebuild -workspace Omnia.xcworkspace -scheme Omnia -configuration Release \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace Omnia.xcworkspace -scheme OmniaiOS -configuration Release \
  -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

The authoritative build is `.github/workflows/release.yml`. Dispatch it with
`unsigned_only=true`. It tests the six packages plus the root package, builds
both Apple targets, archives with signing disabled, packages
`Omnia-iOS-unsigned.ipa`, verifies its payload/version/build/unsigned structure,
and uploads artifact `omnia-1.0.0`.

## Known Limitations

- `Omnia-iOS-unsigned.ipa` cannot be installed directly. It must be signed by
  the user through a separately chosen signing method; signing, provisioning,
  TestFlight, and App Store distribution are not part of this release.
- Physical-device results remain `NOT RUN` until that externally signed build is
  installed. Use `V1_DEVICE_TEST_CHECKLIST.md` and record only observed results.
- A user-supplied OpenAI-compatible endpoint, model, and credential are required.
  Model/capability truth is limited to what that endpoint discovers or the user
  explicitly configures.
- The short-prompt framework and prompt library are intentionally deferred to
  post-v1, together with voice, sync, workspaces, plugins, and built-in web or
  image generation.
