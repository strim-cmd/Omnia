---
title: Engineering Command Interface Specification
document_id: CMD-000
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
  - .ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md
  - .ai/prompts/workflows/
  - .ai/prompts/tasks/
  - .ai/checklists/
supersedes: []
tags:
  - ai
  - command
  - interface
  - specification
  - governance
---

# Engineering Command Interface Specification

> The architectural contract for the Engineering Command Interface. Establishes the command grammar, the complete supported command set, and the resolution rules that make the command interface the single supported user interaction surface of the Engineering Platform.

## Executive Summary

The Engineering Command Interface is the single supported user interaction surface of the Engineering Platform. Every supported user request is expressed as a command from a canonical, repository-defined set. The interface defines how commands are formed (grammar), which commands are supported (the command set), and how each command resolves to execution (resolution through the Workflow Registry). Any input that is not a supported command is reported and never executed.

## Purpose

This specification defines the rules by which the user interacts with the Engineering Platform. It replaces free-form engineering instructions with a deterministic command surface: the user states intent as a command, and the command resolves to a repository-defined workflow through the Workflow Registry.

## Scope

This specification covers:

- The command grammar.
- The complete supported command set.
- Command resolution rules.
- Handling of unrecognized commands.
- The interaction and language rules of the command interface.

This specification does not define the internal execution model, state management, or decision gates of the Orchestrator; those are defined in the Workflow Orchestrator specification (`.ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md`).

## Requirements

### Command Grammar

1. A command is a short, task-oriented statement of intent. It expresses **what** to achieve, never **how** to achieve it.
2. A command follows the form **Verb [Object]**:
   - **Verb** — the action (for example, `Complete`, `Review`, `Prepare`, `Create`).
   - **Object** — the artifact the action applies to, when required (for example, `Issue #N`, `PR #N`, `Release vX.Y.Z`, `RFC`).
3. A command names the artifact by its identifier (issue number, pull request number, version) and does not restate repository rules, workflows, or conventions.
4. The same intent always produces the same command. Commands are canonical; the user does not invent new phrasings that the interface must interpret.

### Supported Command Set

5. The supported command set is defined in the Workflow Registry (`.ai/orchestrator/REGISTRY.md`). The registry is the single source of truth for which commands are supported.
6. A command is supported if and only if its pattern appears in the registry's command-pattern column.
7. The supported command set is reviewed and extended only through the registry's adding-entries procedure. The interface never invents commands that are absent from the registry.

### Resolution

8. Every command resolves through the Workflow Registry before any execution begins.
9. Resolution uses the most specific match against the registry command patterns.
10. Resolution produces the workflow, task prompt, checklist, and decision gates that govern the execution.
11. Before executing a resolved command, the agent loads project state from `.ai/context/PROJECT_STATE.md` and task-specific state from the referenced GitHub artifact.

### Unrecognized Commands

12. If a command pattern does not match the registry, the agent MUST NOT execute it.
13. The agent reports the unrecognized command in the user's preferred language and asks for clarification.
14. The agent MAY suggest the closest supported command from the registry to guide the user.

### Interaction and Language

15. The Engineering Command Interface is the **single supported user interaction surface**. User interaction with the Engineering Platform occurs only through supported commands and the interactive decision gates they trigger.
16. Interactive decision gates (blocking fixes, clean merges, non-blocking confirmations) are part of the command interface and follow the Workflow Orchestrator specification.
17. Engineering artifacts are always written in English.
18. All user-facing interaction — command reporting, summaries, questions, and recommendations — is written in the user's preferred language, inferred from how the user communicates.

## Non-Goals

- The interface does not interpret free-form engineering instructions. Unsupported phrasing is reported, not interpreted.
- The interface does not require the user to specify process, workflows, checklists, or conventions.
- The interface does not replace the Workflow Registry or the Workflow Orchestrator; it is the user-facing surface through which they are invoked.

## Related Documents

- `.ai/AI_CONSTITUTION.md` — the governing rules, including Intent-Driven Operation and the Workflow Orchestrator section
- `.ai/orchestrator/REGISTRY.md` — the authoritative command-to-workflow dispatch table and the supported command set
- `.ai/orchestrator/README.md` — the Workflow Orchestrator overview
- `.ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md` — the execution model, state management, and decision gates
- `.ai/prompts/workflows/` — the workflow definitions resolved through the registry
- `.ai/prompts/tasks/` — the task prompts resolved through the registry
- `.ai/checklists/` — the validation criteria applied during execution
