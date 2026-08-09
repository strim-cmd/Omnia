---
title: Request for Comments — Validation Suite Automation
document_id: RFC-001
version: 0.1.0
status: Draft
owner: Chief AI Architect
project: Omnia
created: 2026-08-04
last_updated: 2026-08-04
related_documents:
  - the platform-validation specification
  - the platform-validation checklist
  - the platform-validation workflow
  - the platform-validation task
  - the orchestrator registry
  - Documentation/Development/Retrospectives/INFRASTRUCTURE_SPRINT_1_RETROSPECTIVE.md
supersedes: []
tags:
  - proposal
  - rfc
  - engineering-platform
  - validation
---

> **Internal engineering-process record.** This document belongs to the project's private engineering-process framework, which is intentionally not included in the public repository. It is retained here for the project's historical record.

# Request for Comments — Validation Suite Automation

> Proposes executing the Engineering Platform Validation Suite (VAL-000) as an automated script that performs its checks mechanically, with the agent invoking and interpreting the script instead of re-executing the checks ad hoc on every platform change.

## Summary

The Validation Suite is currently executed by the agent manually applying the checks in `the platform-validation checklist` each time the platform is validated. This RFC proposes adding a repository-defined script that encodes those checks so the suite runs mechanically and deterministically. The agent invokes the script through the `Validate Engineering Platform` command, interprets its output, and applies the standard decision gates to the result.

## Motivation

VAL-000 defines the suite's checks and pass criteria, but the checks themselves are performed by the agent re-deriving them from the checklist on every invocation. The EP-001 retrospective (backlog item 2) identifies the same pattern for package verification as a gap: "a script or test target that performs the dependency, layer, and acyclicity checks in one command, replacing the ad-hoc greps of the verification phase." The Validation Suite has the same property today: its execution depends on the agent correctly re-deriving every check from prose, which is slower, more error-prone, and harder to reproduce than a single deterministic script. A scripted suite would make validation output comparable across runs and would catch platform defects before they are reviewed.

## Detailed Design

Add a validation script to the Engineering Platform, located at `the platform-validation script` (Git Bash compatible, matching the Windows shell used by the engineering platform), invoked via the `Validate Engineering Platform` command.

The script encodes the seven VAL-000 categories:

1. **Reference resolution.** Extract inline file references and front matter `related_documents` from `the AI engineering framework` documents; fail on any reference that does not resolve to an existing file.
2. **Registry integrity.** Resolve each Workflow Registry entry's workflow, task, and checklist paths; fail on missing targets.
3. **Version and identifier consistency.** Fail on duplicate `document_id` values across `specifications/`, `orchestrator/`, and `standards/`; fail on version references that disagree with referenced documents' front matter.
4. **Document structure.** Fail on formal documents in `specifications/`, `orchestrator/`, and `standards/` that lack YAML front matter with title, version, and status.
5. **Absence of placeholders.** Fail on unresolved template markers or placeholder text in `the AI engineering framework` documents.
6. **Style artifacts.** Fail on prose double-hyphen (`--`) em-dash usage outside inline code spans and CLI flags.
7. **Absence of contradictions.** Fail on documents that contradict a document they reference.

The script prints a per-category PASS/FAIL report and exits non-zero when any category fails. The agent remains the executor and interpreter: the script does not approve, reject, or merge changes. The decision gates from ORCH-000 continue to apply to the script's output. The agent invokes the script when the `Validate Engineering Platform` command resolves; if the script cannot run in the current environment, the agent falls back to executing the checklist manually and reports the fallback.

## Alternatives

- **Keep the manual checklist only.** No new artifact; relies on the agent re-deriving checks from prose. Rejected: keeps the exact reproducibility gap that motivates this RFC, and the retrospective already classifies this pattern as a backlog gap.
- **Automate via the product CI pipeline.** Run the suite in GitHub Actions on every PR. Rejected: CI pipeline is a separate backlog item (item 1) and depends on Linux/macOS build infrastructure that does not exist yet; the suite should be executable locally regardless of CI.
- **Full framework test target.** Implement the suite as a Swift package test target. Rejected: the platform documents live in `the AI engineering framework`, not in a Swift module; the suite is a documentation-integrity check, not product code, and a script keeps it environment-light.

## Trade-offs

- **Benefit:** deterministic, comparable, faster validation; platform defects surface mechanically instead of by agent re-derivation.
- **Cost:** one new script to author and maintain in sync with VAL-000; risk that the script drifts from the spec if either changes without the other.
- **Risk:** the script is platform-dependent (Git Bash); mitigated by the documented manual fallback.
- **Non-goal:** this RFC does not implement CI, automated package verification, or any other backlog item; it automates only the Validation Suite defined by VAL-000.

## Migration

1. Author the script and register its invocation in the `Validate Engineering Platform` workflow and task.
2. Run the script against `the AI engineering framework` and confirm it matches the manual checklist results.
3. Update VAL-000 and the checklist to reference the script as the primary execution mechanism, keeping the manual checklist as the fallback and the reference for the checks.
4. Ratify the change through the standard review gates.

## Open Questions

1. Should the script live in `the project scripts`, or should it be placed with the product code as a repository-level tool?
2. Should the script be required for every platform change, or only for changes to the platform's own documents?
3. Should the suite's output be recorded as an artifact, or is the exit code sufficient for the decision gates?

## Decision

**Accepted** — ratified for the EP-005 execution-path validation exercise on 2026-08-04. The RFC gate operated as specified: the agent ran the Design workflow, created the RFC, and paused until a human decision was recorded. The script described in the Detailed Design is not implemented by this exercise; it remains deferred to the Engineering Platform v2 backlog to avoid expanding the platform's documented surface.
