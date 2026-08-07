---
title: Workflow Orchestrator
version: 1.0.0
status: Ratified
owner: Chief AI Architect
project: Omnia
created: 2026-08-04
last_updated: 2026-08-04
related_documents:
  - .ai/AI_CONSTITUTION.md
  - .ai/orchestrator/REGISTRY.md
  - .ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md
  - .ai/prompts/workflows/
  - .ai/prompts/tasks/
tags:
  - ai
  - orchestrator
  - workflow
  - governance
---

# Workflow Orchestrator

> The execution engine behind intent-driven commands. Transforms concise user intent into repository-defined workflows.

## Purpose

The Workflow Orchestrator is the single dispatch mechanism for all engineering commands. It resolves user intent to a deterministic workflow path, executes through defined stages and decision gates, and keeps all execution state in the repository rather than in tool session context.

## Architecture

See: `.ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md`

## Structure

```text
.ai/orchestrator/
├── README.md        — this file
└── REGISTRY.md      — the authoritative command-to-workflow dispatch table
```

## Registry

The Workflow Registry (`REGISTRY.md`) is the single source of truth for command dispatch. Every command pattern maps deterministically to a workflow, task, pipeline (when populated), checklist, and set of decision gates. The agent reads the registry, matches the intent, and executes the defined path. When a row's `Pipeline` column is populated, the agent executes the referenced pipeline as the stage-level coordination of the resolved workflow.

## How It Works

1. **Intent arrives** — the user issues a command (e.g., `Complete Issue #45.`).
2. **Registry resolution** — the agent matches the command pattern against `REGISTRY.md` and resolves the workflow, task, checklist, and gates.
3. **State loading** — the agent reads `PROJECT_STATE.md` and the referenced GitHub artifact to determine current state.
4. **Execution** — the resolved workflow runs through its defined stages.
5. **Gate application** — decision gates are applied per the orchestrator specification.
6. **Completion or loop** — the workflow completes or loops (e.g., review → fix → re-review).

## Recovery

Execution is always resumable. Because state is repository-derived (read from `PROJECT_STATE.md` and GitHub artifacts), an interrupted session re-reads the registry and project state to determine the next step. The orchestrator never depends on tool session context for state.

## Language Rules

- All engineering artifacts (code, commits, PRs, issues, documentation) are in English.
- All user interaction (summaries, questions, recommendations) is in the user's preferred language, inferred from the user's communication.

## Related Documents

- `.ai/AI_CONSTITUTION.md` — governing rules, including Workflow Orchestrator section
- `.ai/orchestrator/REGISTRY.md` — the command dispatch table
- `.ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md` — the architectural contract
- `.ai/specifications/PIPELINE_SPECIFICATION.md` — pipeline definitions that realize workflows
