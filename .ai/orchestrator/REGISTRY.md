---
title: Workflow Registry
document_id: ORCH-REG-001
version: 1.1.0
status: Ratified
owner: Chief AI Architect
project: Omnia
created: 2026-08-04
last_updated: 2026-08-04
related_documents:
  - .ai/AI_CONSTITUTION.md
  - .ai/orchestrator/README.md
  - .ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md
  - .ai/specifications/COMMAND_INTERFACE_SPECIFICATION.md
  - .ai/prompts/workflows/issue-lifecycle.md
  - .ai/prompts/workflows/review.md
  - .ai/prompts/workflows/release.md
  - .ai/prompts/workflows/documentation.md
  - .ai/prompts/workflows/design.md
  - .ai/prompts/workflows/platform-validation.md
  - .ai/prompts/tasks/complete-issue.md
  - .ai/prompts/tasks/review-pr.md
  - .ai/prompts/tasks/prepare-release.md
  - .ai/prompts/tasks/create-document.md
  - .ai/prompts/tasks/create-rfc.md
  - .ai/prompts/tasks/create-api.md
  - .ai/prompts/tasks/validate-platform.md
  - .ai/checklists/code-review.md
  - .ai/checklists/documentation-review.md
  - .ai/checklists/platform-validation.md
  - .ai/specifications/PIPELINE_SPECIFICATION.md
tags:
  - ai
  - orchestrator
  - registry
  - governance
---

# Workflow Registry

> The single source of truth for command-to-workflow dispatch. Every command pattern maps deterministically to a workflow, task, checklist, and decision gates.

## Purpose

The Workflow Registry is the dispatch table that the Workflow Orchestrator uses to resolve user intent into a concrete execution path. It replaces ad-hoc command interpretation with a deterministic, repository-driven mapping.

The agent MUST resolve every command against this registry before executing. The agent MUST NOT invent workflow paths that are not listed here.

## Registry

| Command Pattern | Workflow | Task | Pipeline | Checklist | Decision Gates |
| --- | --- | --- | --- | --- | --- |
| `Complete Issue #N` | `workflows/issue-lifecycle.md` | `tasks/complete-issue.md` | — | `checklists/code-review.md` | Blocking → auto-fix + re-review loop; Clean → auto-merge; Non-blocking → interactive confirmation |
| `Review PR #N` | `workflows/review.md` | `tasks/review-pr.md` | — | `checklists/code-review.md` | Blocking → report with rationale; Clean → approve and record; Approve with Recommendations → summarize and ask before merge |
| `Implement PR #N` | `workflows/implementation.md` | `tasks/implement-pr.md` | — | — | Verify tests pass, documentation updated |
| `Prepare Release vX.Y.Z` | `workflows/release.md` | `tasks/prepare-release.md` | — | — | Human approval gate per pipeline |
| `Create Document` | `workflows/documentation.md` | `tasks/create-document.md` | `pipelines/NEW_DOCUMENT_PIPELINE.md` | `checklists/documentation-review.md` | Architectural review gate |
| `Create RFC` | `workflows/design.md` | `tasks/create-rfc.md` | — | — | Human ratification gate |
| `Create API Specification` | `workflows/design.md` | `tasks/create-api.md` | — | — | Human ratification gate |
| `Create Issue` | `workflows/github.md` | `tasks/create-issue.md` | — | — | Label and milestone validation |
| `Update Issue #N` | `workflows/github.md` | `tasks/update-issue.md` | — | — | Acceptance criteria preservation |
| `Close Issue #N` | `workflows/github.md` | `tasks/close-issue.md` | — | — | Verify acceptance criteria met |
| `Create Milestone` | `workflows/github.md` | `tasks/create-milestone.md` | — | — | Roadmap-derived validation |
| `Validate Engineering Platform` | `workflows/platform-validation.md` | `tasks/validate-platform.md` | — | `checklists/platform-validation.md` | Blocking → fix and re-run; Clean → certify integrity; findings reported before change ratification |
| `Continue <Sprint>` | Re-read `PROJECT_STATE.md`; resolve next task; dispatch through this registry | — | — | Per resolved task | Per resolved task |

## Resolution Rules

1. **Exact match first.** Match the command pattern against the leftmost column. Use the most specific match available.
2. **Registry is authoritative.** If a command pattern is not in this table, the agent MUST NOT execute it. Instead, report the unrecognized command and ask for clarification, per the Engineering Command Interface specification (`.ai/specifications/COMMAND_INTERFACE_SPECIFICATION.md`).
3. **State before action.** Before executing any resolved workflow, read `PROJECT_STATE.md` and the referenced GitHub artifact to determine current state.
4. **Recovery.** If an execution is interrupted, re-read this registry and `PROJECT_STATE.md` to determine the next step. Do not rely on session context.
5. **Gate semantics.** Decision gates are defined in the Workflow Orchestrator specification (`.ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md`). The agent MUST apply the correct gate type for each workflow.
6. **Pipeline resolution.** When the `Pipeline` column of a resolved row is populated, the agent executes the referenced pipeline (`.ai/pipelines/`) as the stage-level coordination of the resolved workflow, per the Pipeline specification (`.ai/specifications/PIPELINE_SPECIFICATION.md`). The pipeline never changes the command's inputs, outputs, or acceptance path; it adds documented stage coordination. An empty `Pipeline` column (`—`) means the workflow is executed without a declared pipeline.

## Adding Entries

New command patterns are added to this registry when:

1. A new workflow and task are defined in `.ai/prompts/workflows/` and `.ai/prompts/tasks/`.
2. The new entry is reviewed against the Workflow Orchestrator specification.
3. The registry version is incremented.

Entries are never removed; deprecated entries are marked deprecated and retained for reference.

A pipeline is attached to an existing row by populating its `Pipeline` column with the pipeline's path under `.ai/pipelines/`. The referenced pipeline file MUST exist before the entry is ratified. Attaching a pipeline does not change the command set; it adds stage-level coordination to the resolved workflow.

## Related Documents

- `.ai/orchestrator/README.md` — orchestrator overview and architecture
- `.ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md` — the architectural contract
- `.ai/specifications/COMMAND_INTERFACE_SPECIFICATION.md` — the single supported user interaction surface and the canonical command set
- `.ai/specifications/PLATFORM_VALIDATION_SPECIFICATION.md` — the Validation Suite contract
- `.ai/AI_CONSTITUTION.md` — governing rules
