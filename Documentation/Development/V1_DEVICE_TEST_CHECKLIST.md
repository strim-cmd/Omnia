# Omnia 1.0.0 Physical-Device Test Checklist

Use only an externally signed copy of the authoritative unsigned IPA. Mark every
row `PASS`, `FAIL`, `BLOCKED`, or `NOT RUN` and attach concise evidence. Every
`FAIL` must be triaged as P0, P1, or P2. Nothing in this document is pre-marked
as passed.

## Environment

| Field | Value |
|---|---|
| Device model | |
| OS version | |
| App version/build | `1.0.0 (1)` |
| Artifact workflow run / source SHA | |
| Install type | Clean / Upgrade |
| Tested endpoint/model (no credential) | |
| Tester/date | |

## Install and Launch

| Check | Status | Evidence / notes |
|---|---|---|
| Externally sign and install with the tester's chosen method | NOT RUN | |
| Clean launch | NOT RUN | |
| Upgrade preserves existing data | NOT RUN | |
| No crash, blank root, or launch loop | NOT RUN | |
| About reports version `1.0.0` and build `1` | NOT RUN | |

## Onboarding, Providers, and Models

| Check | Status | Evidence / notes |
|---|---|---|
| No-provider state exposes Add Provider | NOT RUN | |
| Add Provider, Test Connection, and save | NOT RUN | |
| Edit provider and retest | NOT RUN | |
| Invalid key, endpoint, and model errors are actionable | NOT RUN | |
| Active/default provider and model remain coherent | NOT RUN | |
| Per-conversation provider/model survives relaunch | NOT RUN | |
| Unavailable model blocks or requests correction without silent redirect | NOT RUN | |
| Provider deletion removes its credential/reference | NOT RUN | |
| Cancel/back from setup leaves recoverable state | NOT RUN | |

## Chat and Generation

| Check | Status | Evidence / notes |
|---|---|---|
| Create chat and send text | NOT RUN | |
| Thinking, streaming, and completed states are distinct | NOT RUN | |
| Stop preserves an interrupted partial response | NOT RUN | |
| Retry and Continue do not duplicate the user message | NOT RUN | |
| Navigate A → B → A during streaming | NOT RUN | |
| Navigate Providers / Settings / About during streaming | NOT RUN | |
| Lock/unlock and background/foreground during generation | NOT RUN | |
| No duplicate or cross-conversation chunks | NOT RUN | |
| History and interrupted/completed state survive relaunch | NOT RUN | |

## Attachments

| Check | Status | Evidence / notes |
|---|---|---|
| Send one photo | NOT RUN | |
| Send multiple images | NOT RUN | |
| Add through the Files picker | NOT RUN | |
| Send a PDF | NOT RUN | |
| Send a plain-text document | NOT RUN | |
| Remove a staged attachment before send | NOT RUN | |
| Unsupported type produces clear validation | NOT RUN | |
| Per-file, total-size, and count limits are enforced | NOT RUN | |
| Unsupported/unknown model capability blocks safely | NOT RUN | |
| Provider/model change revalidates staged attachments | NOT RUN | |
| Attachment history reloads and conversation deletion cleans files | NOT RUN | |

## Conversation, Markdown, and Errors

| Check | Status | Evidence / notes |
|---|---|---|
| Rename persists and auto-title never overwrites it | NOT RUN | |
| Search, date groups, swipe actions, and delete are predictable | NOT RUN | |
| Headings, lists, quotes, emphasis, and safe links render | NOT RUN | |
| Inline code and fenced code render with language label | NOT RUN | |
| Long code scrolls horizontally and Copy Code works | NOT RUN | |
| Long streaming Markdown remains stable | NOT RUN | |
| Offline, unauthorized, model, timeout, rate-limit, and server errors recover safely where feasible | NOT RUN | |
| Error recovery creates no duplicate messages or conversations | NOT RUN | |

## Settings, UI, Accessibility, and Privacy

| Check | Status | Evidence / notes |
|---|---|---|
| Clear Data confirmation states exact scope and removes that scope | NOT RUN | |
| Small and large iPhone layouts keep primary actions visible | NOT RUN | |
| iPad layout keeps primary actions visible | NOT RUN | |
| Light and Dark appearance remain readable | NOT RUN | |
| Keyboard dismisses correctly and unsent draft survives navigation/relaunch | NOT RUN | |
| Dynamic Type, including accessibility sizes, does not clip primary controls | NOT RUN | |
| VoiceOver order, labels, hints, traits, and announcements cover the primary flow | NOT RUN | |
| Rotation and safe areas behave on supported device classes | NOT RUN | |
| No overflow or literal localization keys appear | NOT RUN | |
| Diagnostics/logs reveal no credential, message, or file content | NOT RUN | |

## Failure Triage

| Check / evidence link | Severity (P0/P1/P2) | Owner | Resolution / follow-up |
|---|---|---|---|
| | | | |

Unsigned installation limitation: the CI artifact is intentionally unsigned and
is not directly installable. A `BLOCKED` install result caused solely by the lack
of external signing is not an Omnia runtime failure; signing remains outside the
v1.0.0 scope.
