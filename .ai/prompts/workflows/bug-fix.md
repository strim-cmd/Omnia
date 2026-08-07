# Bug-Fix Workflow

Reusable process for handling defects in Omnia end to end: report, record, triage, reproduce, fix, verify, review, merge, and close.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process. A bug report is recorded as a GitHub Issue, and its completion runs through the Issue Lifecycle workflow (`issue-lifecycle.md`).

## Purpose

A bug is a defect: behavior that differs from the documented contract (DES/ARC) or from the Product Charter. This workflow defines how a bug is recognized, recorded in GitHub as a BUG issue, triaged, reproduced, fixed, verified, and closed — consistently for human and AI contributors.

## Preconditions

1. `gh` is installed and authenticated (`gh auth status`).
2. The bug issue template exists (`.github/ISSUE_TEMPLATE/bug.md`).
3. The label taxonomy exists: `type:*`, `layer:*`, `priority:*`.
4. A roadmap-derived milestone is available when the bug is scheduled.
5. The agent has read the context documents and standards listed in `.ai/README.md`.

## Steps

### 1. Recognize and report

A bug may be reported by a human or an AI agent. A complete report states:

- **Summary** — one sentence describing the defect.
- **Steps to reproduce** — minimal, ordered, reproducible.
- **Expected behavior** — what should happen.
- **Actual behavior** — what actually happens, errors verbatim; never secrets or conversation content (`.ai/standards/SECURITY.md`).
- **Impact** — what is affected and how severely.

For a regression, record the last known-good version or commit. Unknowns are stated as unknowns, never assumed. Never invent requirements (`.ai/AI_CONSTITUTION.md`).

### 2. Create the BUG in GitHub

1. Use the bug template (`.github/ISSUE_TEMPLATE/bug.md`) — title prefixed `[Bug] `, `type:bug` label applied by the template.
2. Apply exactly one `layer:*` label (when the defect touches a layer) and exactly one `priority:*` label. Never create ad-hoc labels.
3. Assign the roadmap-derived milestone when the work is scheduled.
4. Write acceptance criteria and reference the governing documents (DES/ARC).
5. Create with `gh issue create` following the GitHub workflow (`github.md`). A bug issue is tracked like any issue; once created, "Complete Issue #N" dispatches through the registry to the Issue Lifecycle workflow.

### 3. Triage

- Determine priority: `priority:high` blocks or unblocks the critical path; `priority:medium` is important but not blocking; `priority:low` is nice to have.
- Determine the owning layer: Presentation → Application → Domain → Infrastructure → Foundation. Dependencies point downward only; the fix lives in the owning layer (`.ai/AI_CONSTITUTION.md`, `.ai/standards/SWIFT.md`).
- A defect in a frozen contract (DES/ARC) may require a specification revision or an RFC before a fix is accepted (`.ai/AI_CONSTITUTION.md` Authority).

### 4. Reproduce and isolate

1. Reproduce with the recorded steps; record the result in the issue.
2. Identify the root cause. Fix the root cause, never the symptom.
3. Write a failing regression test first (RED) following `.ai/standards/TESTING.md`, pinned to the owning layer's test suite.

### 5. Fix

1. Follow the Implementation workflow (`implementation.md`) — smallest change that satisfies the requirement, layered architecture, native Apple APIs, Swift 6 with strict concurrency.
2. Make the regression test pass (GREEN); confirm no existing test regresses.
3. Commit with the Conventional Commit type `fix:` referencing the issue (`.ai/standards/GIT.md`).

### 6. Verify

1. Full unit-test pass on the Linux build (all packages, 0 failures and 0 warnings).
2. If the change affects packaging, platform configuration, or CI, re-run the Release pipeline (`release.md`) and confirm green.
3. Update the affected documentation (`.ai/standards/DOCUMENTATION.md`); a change is complete only when its documentation is updated.

### 7. Pull request, review, merge

Follow the Issue Lifecycle workflow (`issue-lifecycle.md`): branch → commit → push → PR with `Closes #N` → review against `checklists/code-review.md` → merge. Security-sensitive bug fixes require explicit review before merge.

### 8. Close

1. Verify the issue's acceptance criteria are met.
2. Close the issue (`gh issue close`), move the project item to Done, following the GitHub workflow (`github.md`).
3. Update `.ai/context/PROJECT_STATE.md` when the fix changes project state.
4. Report the outcome in the user's preferred language.

## Rules

- **One issue per defect.** Do not merge unrelated fixes into a bug PR.
- **A fix is not done without a regression test** that proves the defect is fixed and stays fixed.
- **Fix the root cause.** Record the root cause in the issue; a fix that masks the symptom is rejected.
- **Never include secrets** — API keys, tokens, credentials, or conversation content — in a bug report, comment, or commit (`.ai/standards/SECURITY.md`).
- **Security-sensitive bugs** (credentials, transport, data integrity) require explicit review before merge.
- **Frozen contracts** are changed only through specification revision; a fix that violates a frozen contract is not accepted.
- **Language separation.** Engineering artifacts (issues, commits, PRs, documentation) are in English; user interaction is in the user's preferred language.

## Exit Criteria

- A GitHub BUG issue exists for every defect, conforming to the bug template with the correct labels and milestone.
- The root cause is identified and recorded.
- A regression test is added and passing; the full suite is green on the Linux build.
- The fix is merged through a reviewed pull request and the issue is closed with its acceptance criteria met.
- Documentation and `.ai/context/PROJECT_STATE.md` are updated when affected.
