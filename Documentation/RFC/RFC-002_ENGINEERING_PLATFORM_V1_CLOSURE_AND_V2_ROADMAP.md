---
title: Request for Comments — Engineering Platform v1 Closure and v2 Roadmap
document_id: RFC-002
version: 0.1.0
status: Draft
owner: Chief AI Architect
project: Omnia
created: 2026-08-04
last_updated: 2026-08-04
related_documents:
  - the platform version record
  - the project constitution
  - the orchestrator registry
  - the workflow-orchestrator specification
  - the command-interface specification
  - the platform-validation specification
  - the pipeline specification
  - Documentation/Development/Retrospectives/INFRASTRUCTURE_SPRINT_1_RETROSPECTIVE.md
  - Documentation/Development/Retrospectives/EP_001_FOLLOWUP_WORKFLOW_ORCHESTRATOR_VALIDATION.md
  - Documentation/Development/Retrospectives/EP_005_EXECUTION_PATH_VALIDATION.md
  - Documentation/RFC/RFC-001_VALIDATION_SUITE_AUTOMATION.md
supersedes: []
tags:
  - proposal
  - rfc
  - engineering-platform
  - roadmap
---

> **Internal engineering-process record.** This document belongs to the project's private engineering-process framework, which is intentionally not included in the public repository. It is retained here for the project's historical record.

# Request for Comments — Engineering Platform v1 Closure and v2 Roadmap

> Proposes ratifying Engineering Platform v1 as complete and validated, closing it as a milestone, and defining the Engineering Platform v2 roadmap from the deferred backlog, the identified realization gap, and the RFC-001 automation decision.

## Summary

Engineering Platform v1 — the framework manifest FRAMEWORK-001 v3.2.0 — has delivered a complete, ratified, and validated engineering surface: governance (constitution, four specifications, agents), orchestration (registry-driven dispatch, decision gates), operational (workflows, tasks), production (templates), validation (checklists, Validation Suite), and realization (two ratified pipelines). Every property of the Workflow Orchestrator (ORCH-000) has been validated by observed execution (RETRO-003), and the Validation Suite (VAL-000) passes. This RFC proposes ratifying v1 as complete, closing it as a milestone, and adopting a v2 roadmap that resolves the deferred backlog rather than extending the v1 surface.

## Motivation

The Engineering Platform has reached a stable, validated state. EP-001 through EP-005 are closed; RETRO-003 confirms all three previously untested orchestrator paths now behave as specified. The remaining work is not unfinished v1 scope but deferred backlog and a known realization gap:

- The eight Engineering Platform v2 backlog items in RETRO-001 are unimplemented by design.
- The pipelines (PIPELINE-001, PIPELINE-002) are ratified but not wired into the Workflow Registry dispatch.
- RFC-001 (Validation Suite automation) was accepted as an exercise with the script deferred to the backlog.

Without an explicit v1 closure and a v2 roadmap, deferred items accumulate without a governing direction and the realization gap is neither acknowledged nor scheduled. A ratified v2 roadmap makes the next engineering-platform work deterministic and traceable, consistent with the project-state and issue-based workflow already in use.

## Detailed Design

### 1. Ratify Engineering Platform v1 closure

Declare FRAMEWORK-001 v3.2.0 (CONST-001 v1.6.0, ORCH-000, CMD-000, VAL-000, PIPELINE-000) the ratified Engineering Platform v1. Record closure in `PROJECT_STATE.md` and create a closed Engineering Platform v1 milestone on GitHub for traceability. No new functionality is added by this closure.

### 2. Adopt the Engineering Platform v2 roadmap

The v2 roadmap is the governing plan for all engineering-platform work after v1. It is organized into four tracks derived from the deferred backlog, the realization gap, and RFC-001:

**Track A — Realization integration**
- Wire the two ratified pipelines (PIPELINE-001, PIPELINE-002) into the Workflow Registry dispatch so the registry resolves through the pipelines that realize each workflow.

**Track B — Automation**
- Implement RFC-001: a `validate-platform.sh` script encoding the seven VAL-000 categories, invoked through the `Validate Engineering Platform` command, with the manual checklist retained as fallback.
- Automated package verification: a script or test target performing dependency, layer, and acyclicity checks in one command (backlog item 2).

**Track C — Verification**
- Black-box package-surface suite that imports `OmniaInfrastructure` without `@testable` (backlog item 3).
- CI pipeline running all four packages' tests on Linux and macOS for every PR and on merge (backlog item 1).
- Docs-drift check that README's Project Status matches `PROJECT_STATE.md`'s `current_sprint` (backlog item 6).

**Track D — Governance and tooling**
- Recurring retrospective template reused each sprint (backlog item 8).
- Review sign-off for security-sensitive changes as an optional human gate (backlog item 7).
- Project-board CLI helper wrapping the item-status GraphQL mutation (backlog item 4).
- Start-sprint checklist that creates sprint issues, validates the base branch, and syncs README status (backlog item 5).

Each v2 item is scheduled as its own issue through the established issue lifecycle with acceptance criteria, the roadmap-derived milestone, and the label taxonomy.

### 3. Sequencing

Recommended order: Track A (realization integration) first because it closes the only ratified-but-unwired surface and makes later pipeline-based items deterministic; then Track B (automation) because the Validation Suite script and package verification reduce manual verification cost; then Track C (verification); then Track D (governance and tooling). The order is a recommendation, not a binding commitment; each item remains independently schedulable.

## Alternatives

- **Extend v1 instead of closing it.** Treat realization integration and automation as additional v1 milestones. Rejected: v1's contract (CONST-001, ORCH-000, CMD-000, VAL-000) is ratified and stable; adding implementation work under v1 would blur the boundary between a ratified contract and its execution and would contradict the deliberate deferral recorded in RETRO-001.
- **No explicit closure.** Let the framework version advance silently as items are added. Rejected: without a ratified v1 baseline and a v2 roadmap, deferred items and the realization gap have no governing direction, and future retrospectives lose the explicit v1/v2 boundary this closure establishes.
- **Reopen the pipelines to change them now.** Rejecting: the pipelines are already ratified; rewiring them is the scheduled Track A work, not a v1 change.

## Trade-offs

- **Benefit:** a ratified v1/v2 boundary gives deterministic direction to engineering-platform work, records closure for traceability, and schedules every deferred item.
- **Cost:** a new milestone and roadmap record to maintain; v2 items still require individual issues and reviews.
- **Risk:** the roadmap could be mistaken for a commitment rather than a plan; mitigated by recording it as a roadmap with recommended sequencing, not binding dates or dependencies.
- **Non-goal:** this RFC does not implement any v2 item; it defines the roadmap only.

## Migration

1. Ratify this RFC through the standard review gates.
2. Record the v1 closure and the v2 roadmap in `PROJECT_STATE.md`.
3. Create the Engineering Platform v1 (closed) milestone and the Engineering Platform v2 milestone on GitHub.
4. Schedule v2 items as GitHub issues under the Engineering Platform v2 milestone.
5. Keep the roadmap in sync with `PROJECT_STATE.md` at each sprint boundary.

## Open Questions

1. Should the Engineering Platform v2 roadmap be a standalone roadmap document under `Documentation/Product/Roadmap/`, or recorded only in `PROJECT_STATE.md`?
2. Should the v2 milestone be scheduled with a target sprint, or kept unscheduled and populated as capacity allows?
3. Is the recommended sequencing (Track A → B → C → D) acceptable, or should any track be reprioritized?

## Decision

**Accepted** — ratified on 2026-08-04. Engineering Platform v1 (FRAMEWORK-001 v3.2.0) is closed as complete and validated. The v2 roadmap tracks (Realization integration, Automation, Verification, Governance and tooling) are adopted as the governing plan for future engineering-platform work. No v2 item is implemented by this RFC; each is scheduled as its own GitHub issue under the Engineering Platform v2 milestone.
