# Omnia Android — M0 Contract Freeze

| | |
| --- | --- |
| **Document** | ANDROID_README |
| **Phase** | M0 — Contract Freeze (documentation only; no Android production code) |
| **Date** | 2026-08-16 |
| **Goal** | **Android 1.0 = a native Android implementation with behavioral parity to the actual Omnia iOS 1.0.0 implementation.** |
| **Audit input** | `Documentation/Development/DESIGN_PARITY_MATRIX.md` (design→code audit of the iOS implementation; see §4) |

## 1. Source-of-truth hierarchy

The Android 1.0 contract is derived from the **actual implemented iOS behavior**, not from every word of the design documents. Where the documents and the implementation disagree, the implementation is the runtime truth. Four categories of behavior are distinguished throughout these documents:

1. **Actual implemented iOS behavior** — verified in the Swift sources and tests (the runtime truth for Android parity).
2. **Documented intended behavior** — what the ratified specs (DES-009..013) describe.
3. **Stale / spec-drift behavior** — design text that no longer matches the implementation (see the discrepancy register in §4 and `ANDROID_PARITY_MATRIX.md`).
4. **Apple-specific behavior** — mechanism-bound to Apple platforms (Keychain, SwiftUI, PhotosUI, VoiceOver, Dynamic Type, UIPasteboard), which Android must realize with native equivalents.
5. **Functionality deferred beyond Android 1.0** — explicitly out of scope for the Android 1.0 contract.

## 2. Documents

| File | Content |
| --- | --- |
| `ANDROID_V1_SCOPE.md` | Android 1.0 scope split into `REQUIRED`, `PLATFORM_SPECIFIC`, `DEFERRED`, and `EXTENSION_POINT`. |
| `ANDROID_ARCHITECTURE.md` | Android module dependency graph; semantics preserved vs. Swift implementation details intentionally not copied. |
| `ANDROID_PARITY_MATRIX.md` | **The primary artifact.** Android-facing parity contract for every iOS capability (provider, generation, conversation, Markdown, errors, settings, privacy). |
| `ANDROID_TEST_MATRIX.md` | Translation of the iOS `V1_DEVICE_TEST_CHECKLIST` into Android verification layers (JVM → instrumentation → device). |
| `ANDROID_MIGRATION_MAP.md` | Mapping of Swift package responsibilities to proposed Android modules and owners. |
| `ANDROID_README.md` | This file. |

## 3. Platform stance

- **Native Android**: Kotlin + Jetpack Compose + kotlinx.coroutines. No cross-platform UI framework.
- **No Android code in M0.** M0 freezes the contract only. M1+ implements modules against it.
- **Dependency principle inherited from iOS**: `core ← domain ← app` and `core ← domain ← data`; `presentation` depends on `app` + `core` only; `app-shell` is the only module that wires everything. `presentation` and `app` must never see `data`. This mirrors the Swift edge rule that only `OmniaApp` references Infrastructure.
- **No third-party dependency without a concrete documented need** (iOS parity rule). Where a platform equivalent is unavoidable (e.g., Android Keystore, Compose), it is standard AndroidX/Platform, not a vendored product framework.
- **Credential boundary**: credentials live only in Android Keystore-backed storage; provider records, configuration, conversations, and attachments hold only references.
- **No analytics / remote telemetry** (iOS v1 rule).

## 4. Discrepancy register (from the iOS audit)

These are explicit source-of-truth discrepancies carried into every Android document:

| ID | Discrepancy | Resolution for Android |
| --- | --- | --- |
| G-01 | **`SendMessageRequest` selection vocabulary.** Design docs (DES-011 §3.1, DES-012 §3.3) still say `userSelection: ProviderIdentity?` / `workspacePreference` / `capabilityPreference`. The implementation ships `SendMessageRequest(conversation:message:modelSelection:)` with a `ProviderModelSelection` (provider + model) pair, persisted per conversation. **Runtime truth = `modelSelection`.** | Android 1.0 models the selection vocabulary as **`ProviderModelSelection` (provider + model)** — the runtime truth. The stale `userSelection/workspacePreference/capabilityPreference` terminology is **not** copied. The discrepancy is recorded, not silently resolved either way. See `ANDROID_PARITY_MATRIX.md` rows P-01, P-06, P-08, GEN-19. |
| G-02 | **Reduce Motion** not explicitly handled in iOS (`accessibilityReduceMotion`); custom springs may run. | Android `REQUIRED` as a platform-specific behavior: respect `Settings.Global.ANIMATOR_DURATION_SCALE == 0` / `MotionEventCompat`-style reduction for drawer, swipe-reveal, and message animations. iOS status: unverified. |
| G-03 | **Foundation error-abort contract** (`isUnrecoverable`/`Description`) is absent from `OmniaFoundation`. | Android core defines typed errors without an abort contract until DES-001 is clarified. Recorded as unresolved spec ambiguity, not a blocker for M0. |
| G-04 | **Background/foreground + lock during generation** — iOS tasks continue off-screen by design; device behavior unverified. | Android 1.0 defines an explicit contract: generation continues while the app is in foreground and across navigation/configuration changes; after **process death**, generation state is recovered from the persisted interrupted/completed record on relaunch (parity with iOS persistence-on-interruption). No foreground Service in v1. |
| G-05 | **Dynamic Type / high contrast** — iOS relies on SwiftUI scaling; clipping at accessibility sizes unverified on device. | Android uses `sp` typography + `fontScale` handling and `Canvas`-independent layouts; verified at the instrumentation + device layers, not claimed from unit tests. |
| G-06 | **macOS keyboard shortcuts** — iOS-only behavior, no evidence. | **Not applicable / not copied** to Android. Android 1.0 does not add a keyboard-shortcut surface beyond Compose `KeyEvent` handling that already maps to menu/back behavior. |
| G-07 | **`AppEdgeConstants.defaultModelName = "omnia-coding"`** is a legacy compatibility value; production catalogs come from **discovery, cache, or explicit manual entry**, never a fabricated default. | Android must never fabricate a default model catalog; the fallback path mirrors discovery → cache → manual entry. |

## 5. What parity means (and does not mean)

- **Means**: every user-visible behavior and data-integrity rule the iOS 1.0.0 implementation demonstrates is reproduced on Android, verified at the appropriate layer (JVM → instrumentation → device).
- **Does not mean**: pixel-identical UI, identical file formats, or copying Swift implementation mechanics (actors, property wrappers, Keychain API calls). See `ANDROID_ARCHITECTURE.md` §4 for the "not copied" list.
- **Honesty rule** (inherited from the iOS scope): device-only iOS items are **not** marked proven merely because package tests pass; Android uses the same standard — device claims require a device run.

## 6. Status of this contract

All six documents are contract-freeze artifacts for **M0**. They define the acceptance surface for M1+; no Android source exists yet, so every parity row is a contract statement with an assigned verification layer, not a test result.
