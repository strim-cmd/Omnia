---
title: Workflow Orchestrator Specification
document_id: ORCH-000
version: 1.0.0
status: Ratified
owner: Chief AI Architect
project: Omnia
created: 2026-08-04
last_updated: 2026-08-04
related_documents:
  - .ai/AI_CONSTITUTION.md
  - .ai/orchestrator/README.md
  - .ai/orchestrator/REGISTRY.md
  - .ai/specifications/PIPELINE_SPECIFICATION.md
  - .ai/prompts/workflows/
  - .ai/prompts/tasks/
  - .ai/checklists/
supersedes: []
tags:
  - ai
  - orchestrator
  - specification
  - governance
---

# Workflow Orchestrator Specification

> The architectural contract for the Workflow Orchestrator. Defines how user intent resolves to execution, how state is managed, and how decision gates operate.

## Executive Summary

The Workflow Orchestrator is the execution engine behind intent-driven commands. It transforms concise user intent into repository-defined workflows through a deterministic, registry-driven dispatch mechanism. All execution state is repository-derived, ensuring resumability and consistency across sessions.

## Design Goals

This specification is designed to achieve:

- **Determinism** — the same intent and project state always produce the same execution path.
- **Repository-driven state** — all state is read from the repository, never from tool session context.
- **Resumability** — every execution can be interrupted and resumed by re-reading the repository.
- **Minimal user interaction** — the agent pauses only when a human engineering decision is required.
- **Language separation** — engineering artifacts in English; user interaction in the preferred language.
- **Traceability** — every execution is traceable through the registry, workflows, and project state.

## Execution Model

The Orchestrator executes through a defined sequence of phases:

### Phase 1: Intent Resolution

1. The agent receives a command from the user.
2. The agent reads the Workflow Registry (`.ai/orchestrator/REGISTRY.md`).
3. The agent matches the command against the registry patterns.
4. If no match is found, the agent reports the unrecognized command and asks for clarification.
5. If a match is found, the agent resolves the workflow, task, checklist, and gates.

### Phase 2: State Loading

1. The agent reads `.ai/context/PROJECT_STATE.md` for current project state.
2. The agent reads the referenced GitHub artifact (Issue, PR, Milestone) for task-specific state.
3. The agent confirms the task is actionable (not blocked, not already completed).
4. If the task requires architectural or product-direction changes, the agent runs the Design workflow and creates an RFC before proceeding.

### Phase 3: Workflow Execution

1. The agent follows the resolved workflow from `.ai/prompts/workflows/`.
2. The agent executes the task prompt from `.ai/prompts/tasks/`.
3. The agent applies the checklist from `.ai/checklists/` where applicable.
4. All engineering artifacts (code, commits, PRs, issues, documentation) are written in English.
5. The agent updates `PROJECT_STATE.md` at appropriate milestones during execution.

### Phase 4: Decision Gates

Decision gates are applied at the conclusion of each workflow. Three gate types exist:

#### Blocking Gate

Blocking issues are issues that prevent approval (checklist failures, security violations, architectural inconsistencies, broken tests).

- The agent fixes blocking issues automatically without asking the user.
- After fixing, the agent re-runs verification (tests, checklist).
- If blocking issues remain, the agent fixes them again.
- This loop repeats until no blocking issues remain.
- The agent NEVER asks the user for permission to fix blocking issues.

#### Clean Gate

A clean pass means the checklist passes fully with no issues and no recommendations.

- The agent merges automatically without asking the user.
- The agent NEVER asks for permission to merge a clean pass.

#### Non-Blocking Gate

Non-blocking recommendations are items that do not prevent approval but could improve the change (style suggestions, minor improvements, optional refactoring).

- The agent summarizes the recommendations in the user's preferred language.
- The agent asks whether to address them before merging.
- The agent waits for the user's decision before proceeding.
- The agent merges only after the user decides.

### Phase 5: Completion

1. Verify the task's acceptance criteria are met.
2. Update GitHub state (close issue, move project item to Done).
3. Update `PROJECT_STATE.md` if applicable.
4. Report completion to the user in their preferred language.

## State Management

### Repository-Derived State

All orchestrator state is read from the repository, never from tool session context:

- **Project state**: `.ai/context/PROJECT_STATE.md`
- **GitHub state**: Issues, PRs, and Milestones via `gh` CLI
- **Workflow dispatch**: `.ai/orchestrator/REGISTRY.md`

### Recovery

If an execution is interrupted:

1. The agent re-reads the Workflow Registry to determine available commands.
2. The agent re-reads `PROJECT_STATE.md` to determine current project state.
3. The agent reads the relevant GitHub artifact to determine task-specific state.
4. The agent determines what step was in progress and resumes from that point.
5. The agent NEVER assumes session context carries over from a previous execution.

## Language Rules

1. **Engineering artifacts** are always in English: source code, commits, pull requests, issues, milestones, documentation, and all repository content.
2. **User interaction** is always in the user's preferred language, inferred from how the user communicates: summaries, questions, recommendations, and completion reports.

## Relationship to Pipelines

The Workflow Orchestrator dispatches workflows. Pipelines (defined per `.ai/specifications/PIPELINE_SPECIFICATION.md`) define the stage-level coordination within those workflows. The orchestrator does not replace pipelines; it provides the entry point through which pipelines are invoked.

## Engineering Rules

1. The orchestrator MUST be deterministic.
2. The orchestrator MUST be resumable.
3. The orchestrator MUST use the Workflow Registry for dispatch.
4. The orchestrator MUST read state from the repository.
5. The orchestrator MUST NOT require the user to specify process.
6. The orchestrator MUST NOT invent workflow paths not in the registry.
7. The orchestrator MUST apply decision gates per this specification.
8. The orchestrator MUST update project state upon completion.

## Related Documents

- `.ai/orchestrator/README.md` — overview and structure
- `.ai/orchestrator/REGISTRY.md` — the command dispatch table
- `.ai/AI_CONSTITUTION.md` — governing rules
- `.ai/specifications/PIPELINE_SPECIFICATION.md` — pipeline definitions
- `.ai/prompts/workflows/` — workflow definitions
- `.ai/prompts/tasks/` — task prompts
