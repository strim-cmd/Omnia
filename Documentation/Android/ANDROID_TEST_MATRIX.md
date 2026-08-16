# Android Test Matrix — Android 1.0 verification layers vs. iOS parity rows

| | |
| --- | --- |
| **Document** | ANDROID_TEST_MATRIX |
| **Phase** | M0 — Contract Freeze |
| **Primary artifact** | Maps every parity row of `ANDROID_PARITY_MATRIX.md` to a verification layer, and translates the iOS test suite + `V1_DEVICE_TEST_CHECKLIST` into Android gates. |
| **Sources** | `ANDROID_PARITY_MATRIX.md` (rows), iOS package test suites (coverage to translate), `Documentation/Development/V1_DEVICE_TEST_CHECKLIST.md` (device checklist to translate). |

## 1. Verification layers

| Layer | Scope | Typical tooling | Parity rows (map keys) |
| --- | --- | --- | --- |
| **JVM** | Pure logic: value types, mapping, validation, limits, auto-title, grouping, safe-link allow-list, redaction, repository round-trip, persistence strictness | JUnit 5 + kotlinx-coroutines-test; no Android runtime | P-04, P-05, P-07, P-08, P-10, P-11, GEN-07…GEN-11, GEN-13, GEN-16, GEN-18, GEN-22, GEN-24, C-02…C-06, M-01, M-03, M-07, E-02…E-05, E-11…E-13, X-01, X-02 |
| **ViewModel** | State machines: streaming condition mapping, conversation-keyed coordinator, identity guard, retry/resume/regenerate, draft store, revalidation | ViewModel + StateFlow tests on JVM (Robolectric only where a framework API is unavoidable) | P-09, P-10, GEN-02, GEN-12, GEN-14, GEN-15, GEN-16, GEN-17, GEN-19, GEN-23, GEN-24, C-08, C-09, E-05, E-10, E-13 |
| **Repo** | Repository + storage: namespaces, per-record isolation, credential reference cleanup, Clear Data scope, lazy dirs | File-store tests on JVM `TemporaryFolder`; content-resolver tests instrumented | P-01, P-04, P-05, P-08, P-10, GEN-18, GEN-22, C-01, C-02, C-08, E-11, E-12, E-13, S-06 |
| **Network** | Provider/transport: adapter DTO mapping, streaming parsing, header-only auth, error translation, model discovery, catalog cache | JUnit + a mock HTTP engine (Ktor MockEngine or OkHttp MockWebServer) — **no real network in CI** | P-02, P-03, P-04, P-06, P-07, P-11, GEN-01, GEN-02, GEN-08, E-01, E-02, E-04, E-06, E-07, E-08, E-09, E-10 |
| **Compose** | UI rendering: screens, drawer, settings, markdown renderer, empty states, TalkBack semantics (content descriptions, custom actions, live regions) | Compose UI tests (`createComposeRule`) on JVM/emulator | P-01, P-06, GEN-05, GEN-06, GEN-07, GEN-10, GEN-12, GEN-13, C-03, C-05, C-06, C-07, M-02, M-03, M-04, M-05, M-06, M-07, S-01, S-02, S-03, S-04, S-07, X-02 |
| **Instr** | Framework + device behaviors: Back/predictive back, rotation, process death/Activity recreation, IME insets, credential Keystore purge, Clear Data scope, TalkBack stream, font scaling, reduced motion, picker flows | `androidx.test` instrumentation on emulator + `adb`-scripted states | P-05, GEN-05, GEN-06, GEN-07, GEN-20, GEN-21, GEN-22, GEN-24, C-07, C-08, S-01, S-02, S-05, S-06, S-07, S-08, S-09, S-10, S-11, S-12, S-13, S-14, S-15 |
| **Device** | Physical-device smoke (phone + tablet): picker UX, background/foreground contract, font scale at max, high contrast, real TalkBack | Manual checklist derived from `V1_DEVICE_TEST_CHECKLIST` | GEN-05, GEN-06, GEN-20, GEN-21, GEN-22, S-05, S-07, S-09, S-10, S-11, S-14, S-15 |

> **Honesty rule:** a row verified only at `Device`/`Instr` is **not** proven by JVM tests. `[iOS unverified]` rows carry Android device obligations below; the checklist is the record of actually running them.

---

## 2. Verification-layer coverage (how many parity rows each layer must cover)

| Layer | Row count (unique parity rows) |
| --- | --- |
| JVM | 32 |
| ViewModel | 14 |
| Repo | 12 |
| Network | 17 |
| Compose | 26 |
| Instr | 22 |
| Device | 11 |

*Counts are the set of distinct REQUIRED/PLATFORM_SPECIFIC parity rows whose Verification cell lists the layer (computed by parsing every row of `ANDROID_PARITY_MATRIX.md` §2–§8 at contract freeze; sum of unique covered rows = 79 = 86 total − 4 DEFERRED − 3 EXTENSION_POINT; uncovered = 0). A row may appear in several layers (defense in depth). Recompute mechanically whenever the matrix changes — never trust a hand-recount.*

---

## 3. iOS suite → Android translation

Each iOS package suite becomes an Android test surface at the same architectural layer (see `ANDROID_MIGRATION_MAP.md`).

| iOS package suite | Android surface | Layer | What must be proven |
| --- | --- | --- | --- |
| OmniaFoundationTests | `:core` tests | JVM | Identifiers, clock, cancellation, environment, lifecycle state machine, semantic version, logging/redaction |
| OmniaDomainTests | `:domain` tests | JVM (+ViewModel) | Aggregate invariants, auto-title precedence, attachment limits, capability gating, provider-model selection value, lifecycle services, error taxonomy |
| OmniaApplicationTests | `:app` tests | JVM (+ViewModel) | Conversation/workspace/provider-connection/configuration services, send-message flow, attachment import + revalidation, boundary validation |
| OmniaInfrastructureTests | `:data` tests | JVM + Repo + Network | File store round-trip + strictness + isolation, credential store errors, adapter mapping, streaming parsing, error translation, catalog cache |
| OmniaPresentationTests | `:presentation` tests | ViewModel + Compose | State→UI condition mapping, streaming presentation, auto-scroll, drafts, coordinator identity guard, markdown segmentation, grouping/search, TalkBack semantics |
| OmniaAppTests | `:app-shell` tests | JVM + Instr | Storage layout, adapter binding routing, first-run bootstrap, launch/copy, app-edge constants |

**Translation invariant:** for every iOS test concept, the Android layer has a test that asserts the same observable behavior — same outcomes, Android syntax. Deleting an Android test is forbidden while its iOS counterpart exists and its parity row is REQUIRED.

---

## 4. Device checklist translation (from `V1_DEVICE_TEST_CHECKLIST.md`)

The iOS device checklist is re-expressed as Android device/emulator checklist categories. Only a physical device or instrumented run proves them.

| Category | Android execution | Parity rows covered |
| --- | --- | --- |
| Clean install/launch + upgrade/data persistence | Emulator clean install; relaunch across process death; version bump preserving data | GEN-22, C-02, S-04 |
| Provider onboarding & connection failure recovery | Instrumented Add Provider → bad key/endpoint → safe copy + form retention; cancel/back recoverable | P-06, S-01, S-12 |
| Chat during generation: navigation, stop/retry/continue, duplicate protection | Instrumented streaming + navigation A→B→A; stop → partial retained; retry → resume; send twice → no duplicates | GEN-12, GEN-14, GEN-15, GEN-16, GEN-17, GEN-20, GEN-23, GEN-24 |
| Background/foreground + lock during generation | **Device**: start streaming, home, lock, relaunch → no cancel, no duplicates, persisted interrupted/completed; `[iOS unverified]` so Android defines and verifies its own contract (G-04) | GEN-21, GEN-22 |
| Attachments: photo picker, file picker, PDF, text, multiple images, limits, revalidation | Device: Photo Picker + SAF flows end-to-end; staged preview; remove before send; limits enforced; provider/model change revalidates | GEN-05, GEN-06, GEN-07, GEN-08, GEN-09, GEN-10, GEN-11, S-11 |
| Markdown + copy: inline/fenced code, language label, long-code scroll, Copy Code, safe links | Compose instrumented + manual: block rendering, copy to clipboard, scroll long code, non-http schemes inert | M-01…M-07 |
| Errors: offline/unauthorized/model/timeout/rate-limit/server/malformed response/interrupted stream | Mock server instrumented: typed failures, safe copy, recovery without duplicates, partial preserved on interruption | E-01…E-10 |
| Settings/UI: Clear Data scope, phone/tablet, light/dark, font scale, accessibility, rotation, keyboard | Device matrix: Clear Data purge (incl. Keystore), tablet layout, dark/light contrast, 200% font scale (no clipped composer), TalkBack primary flow, rotation mid-stream, keyboard draft preservation | S-02, S-03, S-05, S-07, S-09, S-10, S-13, S-15, C-08 |
| Privacy: no secret/message/path leakage | Instrumented log capture asserts redaction across connection, generation, import, removal | X-01, P-03, P-05 |

**Reduce motion (`[iOS gap G-02]`, Android REQUIRED):** instrumented assert that drawer/swipe/message animations honor the reduced-motion / animator-duration-scale setting.

---

## 5. CI gates

| Gate | Contents | Fails the release when |
| --- | --- | --- |
| PR gate | JVM + ViewModel + Repo + Network + Compose unit/UI suites | Any parity row test fails, or a REQUIRED row has no test yet |
| Instrumentation gate | Instr suite on emulator matrix (phone + tablet, min + target API, dark/light, 200% font scale) | Framework/device-behavior rows regress |
| Device sign-off | Manual Device checklist (phone + tablet) before release | Any `Device`-layer row unverified |

---

## 6. Coverage completion rule

- Every `REQUIRED` / `PLATFORM_SPECIFIC` parity row must be covered by ≥1 verification layer, and every layer must be green at its gate before Android 1.0 ships.
- `DEFERRED` and `EXTENSION_POINT` rows need no tests in v1.
- Tracking lives in the **Status** column of `ANDROID_PARITY_MATRIX.md`; this matrix is the proof-of-test map, never the proof itself.
