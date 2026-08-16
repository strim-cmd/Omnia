# Omnia — Native Android

The native Android implementation of Omnia, built for behavioral parity with
the actual iOS 1.0.0 implementation (`Documentation/Android/` is the contract).

## Status

- **M1 — foundation shell** (this codebase): Gradle project, core layers,
  design system, navigation shell (Chat / Providers / Settings / About), and
  the testing + CI infrastructure.
- **Not yet implemented**: providers, networking, credentials, model discovery,
  persistence, streaming, Markdown rendering, and the message pipeline. See
  `ANDROID_V1_SCOPE.md` for the milestone buckets.

## Modules

```
app                     Android application: MainActivity, OmniaApplication,
                        AppContainer (composition root), navigation shell, About.
feature:chat            Chat destination (empty state).
feature:providers       Providers destination (empty state).
feature:settings        Settings destination (theme mode), About entry.
core:designsystem       Material 3 theme tokens, spacing, components, icons.
core:application        Use cases (framework-independent JVM module).
core:domain             Domain model seed (framework-independent JVM module).
core:common             Clock, Identifier, Logger, AppError, DispatcherProvider
                        (framework-independent JVM module).
```

Dependency direction is enforced by construction and by test
(`ArchitectureVerificationTest`): `app -> features -> core:application ->
core:domain -> core:common`; `core:designsystem` is consumed by app and
features only. The core layers are pure-JVM modules and cannot reference
`android.*`/`androidx.*`; the app is the only module that owns Android
bindings (Logcat logger, Main dispatchers, composition root).

iOS naming mirrors: `core:common` -> OmniaFoundation, `core:domain` ->
OmniaDomain, `core:application` -> OmniaApplication, `feature:*` ->
OmniaPresentation, `app` -> OmniaApp.

## Prerequisites

- JDK 17 (Temurin recommended)
- Android SDK with `platforms;android-36` and `build-tools;36.0.0`
  (AGP installs missing SDK components automatically once licenses are
  accepted)
- `ANDROID_HOME` pointing at the SDK

## Developer commands

Run from this directory (`Android/`). The Gradle wrapper is the only supported
entry point.

```bash
# Toolchain check
./gradlew --version

# Compile everything
./gradlew compileDebugKotlin

# Unit tests (JVM + Robolectric, includes Compose UI tests and the
# architecture-verification test)
./gradlew test

# Lint (static analysis over all modules)
./gradlew lint

# Debug APK
./gradlew assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk

# Run all verification gates the CI runs
./gradlew test lint assembleDebug
```

On Windows use `gradlew.bat`; on macOS/Linux use `./gradlew`.

### Running on a device/emulator

M1 verification is JVM/Robolectric-based and does not require a device. To run
the app interactively:

```bash
./gradlew installDebug
```

requires an emulator or connected device (adb). No emulator image is part of
the repo; device smoke tests are out of scope until later milestones
(`ANDROID_TEST_MATRIX.md`).

## Toolchain

| Component | Version |
|---|---|
| Gradle wrapper | 8.13 |
| Android Gradle Plugin | 8.13.2 |
| Kotlin | 2.3.21 |
| Compose BOM | 2026.06.01 |
| compileSdk / targetSdk | 36 |
| minSdk | 26 (Android 8.0) |
| JVM toolchain | 17 |

Versions are pinned in `gradle/libs.versions.toml` (single source of truth).

## Conventions

- UDF everywhere: immutable `UiState` + `ViewModel` + `StateFlow`.
- No DI framework, no service locator: `AppContainer` is the explicit
  composition root; features declare their dependencies as interfaces.
- Logging never includes credentials, API keys, message content, or
  attachment content (see `core/common/.../Logger.kt`).
- M0 contract (`Documentation/Android/`) is authoritative; where a real
  contradiction exists, record it rather than silently deviating.
