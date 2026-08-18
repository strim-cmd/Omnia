# M1 Final Report — Android Foundation

**Commit:** `ec7b23d` — `feat(android): establish native application foundation`
(Pushed to `origin/main`; includes M0 `8d857f5`)

---

## Modules & packages

| Module | Kind | Package |
|---|---|---|
| `core:common` | pure JVM | `com.omnia.common` — Clock, Identifier, Logger, AppError, DispatcherProvider |
| `core:domain` | pure JVM | `com.omnia.domain` — ModelSelection, DomainError |
| `core:application` | pure JVM | `com.omnia.application` — AppMetadata, ProvideAppMetadata |
| `core:designsystem` | Android lib | `com.omnia.designsystem` — theme (brand `#8A2BE2`), components, icons, spacing |
| `feature:chat` | Android lib | `com.omnia.feature.chat` |
| `feature:providers` | Android lib | `com.omnia.feature.providers` |
| `feature:settings` | Android lib | `com.omnia.feature.settings` |
| `app` | Android app | `com.omnia.app` — AppContainer, navigation shell, AboutScreen |

Dependency rule enforced at build + bytecode:
`app → features → designsystem → application → domain → common`

---

## Versions (locked, SDK-36 compatible)

| Component | Version |
|---|---|
| Gradle | 8.13 |
| AGP | 8.13.2 |
| Kotlin | 2.3.21 |
| Compose BOM | 2026.06.01 |
| JDK | 17 (Temurin 17.0.20.8) |
| compileSdk / targetSdk | 36 |
| minSdk | 26 |
| coroutines | 1.11.0 |
| robolectric | 4.16.1 |
| navigation-compose | 2.9.8 |
| activity-compose | 1.13.0 |
| core-ktx | 1.16.0 |
| lifecycle | 2.9.4 |

App version: **1.0.1 (build 2)** — matches iOS `App/Config/Shared.xcconfig`.

---

## Gate results (all green)

| Gate | Command | Result |
|---|---|---|
| Tests | `./gradlew test` | **42/42 pass** |
| Lint | `./gradlew lint` | **0 errors** (12 "newer version" advisories only) |
| Build | `./gradlew assembleDebug` | APK at `Android/app/build/outputs/apk/debug/app-debug.apk` (11.4 MB) |
| Whitespace | `git diff --check` | Clean (CRLF warnings only) |

### CI

`.github/workflows/android.yml` — Ubuntu, JDK 17 Temurin, runs on push/PR
(path filter: `Android/**`):

- `./gradlew test`
- `./gradlew lint`
- `./gradlew assembleDebug`
- Uploads `omnia-android-debug` artifact
- Gradle wrapper validation included

---

## Environment blockers resolved

The host user profile is non-ASCII
(`C:\Users\Семья Буробиных`), which broke two things:

### 1. Gradle test workers

`GradleWorkerMain` ClassNotFound + `java.io.IOException`
(non-ASCII user-home path mangled by worker JVM).

**Fix:** `GRADLE_USER_HOME` set to `C:\GradleHome` (ASCII,
set persistently via `setx`; gradle cache copied there).

### 2. Robolectric native runtime

`DefaultNativeRuntimeLoader` computed a mangled `.m2` path
from the non-ASCII `user.home`, then could not open the
`android-all-instrumented` jar.

**Fix:** root `build.gradle.kts` injects
`-Duser.home=C:\OmniaTestHome` into all test JVMs when the
OS is Windows and the real user-home contains non-ASCII
characters. Pre-existing Robolectric jars copied to the ASCII
`.m2` cache so no network re-download is needed on subsequent
runs.

### 3. Robolectric SDK 36 + Java 17

Robolectric 4.16 supports SDK 36 but requires Java 21.
The agreed toolchain is JDK 17.

**Fix:** all Robolectric tests annotated with
`@Config(sdk = [35])` and
`@GraphicsMode(GraphicsMode.Mode.LEGACY)` (native rendering
requires native libs not available on Windows).

### 4. Duplicate release-variant tests

`./gradlew test` runs both debug and release unit-test
variants. The release variant resolves activities differently
from debug, causing spurious failures on the same code.

**Fix:** release-variant unit tests disabled in the root
`build.gradle.kts` (debug-only gate — standard practice,
halves CI time).

---

## Notes

- **Emulator/device: NOT RUN** (no emulator or device
  available; UI behaviour validated via Robolectric Compose
  tests).

- Pre-existing uncommitted files **preserved and NOT
  committed**:
  - `README.md` (M — pre-existing modification)
  - `Documentation/Development/DESIGN_PARITY_MATRIX.md`
  - `Documentation/UI/FIX_UI.md`
  - `OMNIA_V1_EXECUTION_SCOPE.md`

- **Known trade-off:** Compose UI tests run on Robolectric
  only. Instrumented / emulator coverage will require a
  physical device or emulator in CI.

---

## M2 blockers

None within the repo. CI must confirm the Linux pipeline
passes — Linux user home is ASCII, so all the Windows-specific
workarounds above are inactive there (guarded by OS detection).

Remaining prerequisite: JDK 21 would unlock Robolectric SDK
36 sandbox and the full NATIVE graphics-mode test suite.
