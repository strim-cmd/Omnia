---
title: Engineering Platform Validation Suite Specification
document_id: VAL-000
version: 1.0.0
status: Ratified
owner: Chief AI Architect
project: Omnia
created: 2026-08-04
last_updated: 2026-08-04
related_documents:
  - .ai/AI_CONSTITUTION.md
  - .ai/README.md
  - .ai/orchestrator/REGISTRY.md
  - .ai/specifications/COMMAND_INTERFACE_SPECIFICATION.md
  - .ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md
  - .ai/checklists/platform-validation.md
  - .ai/standards/DOCUMENTATION.md
supersedes: []
tags:
  - ai
  - validation
  - specification
  - governance
---

# Engineering Platform Validation Suite Specification

> The architectural contract for the Engineering Platform Validation Suite. Defines the checks that validate the integrity and consistency of the Engineering Platform itself, and how the suite is invoked and gated.

## Executive Summary

The Engineering Platform Validation Suite is a repository-defined set of checks that validates the Engineering Platform itself — the `.ai` framework. It verifies that platform documents resolve their references, that the Workflow Registry maps only to existing workflows, tasks, and checklists, that versions and document IDs are consistent, that documents conform to the documentation standard, and that no placeholders or contradiction artifacts remain. The suite is invoked as a supported command through the Workflow Registry and is gated by the standard decision gates.

## Purpose

The Engineering Platform is itself an engineering artifact: it defines how engineering work is performed on Omnia. Its integrity is a precondition for deterministic execution. This specification defines the checks that certify that integrity, replacing ad-hoc manual verification with a repeatable, repository-derived suite.

## Scope

This specification covers:

- The validation categories the suite checks.
- The checks within each category and their pass criteria.
- How the suite is invoked through the command interface.
- How the suite integrates with the review decision gates.

This specification does not cover validation of the Omnia product code (the Swift packages), the CI pipeline, or automated package verification; those remain in the Engineering Platform v2 backlog.

## Requirements

### Validation Categories

The suite validates the Engineering Platform across the following categories:

1. **Reference resolution.** Every file reference in `.ai` documents (inline paths and front matter `related_documents`) resolves to an existing file in the repository.
2. **Registry integrity.** Every entry in the Workflow Registry (`.ai/orchestrator/REGISTRY.md`) resolves: the workflow, task, and checklist referenced by each command pattern exist.
3. **Version and identifier consistency.** Every document with a `document_id` in the `specifications/`, `orchestrator/`, and `standards/` directories uses a unique identifier, and version references between documents agree with the documents' own front matter.
4. **Document structure.** Every formal document in the `specifications/`, `orchestrator/`, and `standards/` directories carries YAML front matter with title, version, and status. Formal documents follow the Documentation standard (`.ai/standards/DOCUMENTATION.md`), whose structure requirements apply when applicable.
5. **Absence of placeholders.** No document contains unresolved template markers, lorem ipsum, or placeholder text intended to be replaced before commit. Checklist and review documents that name these markers to define the check are not affected.
6. **Style artifacts.** No prose uses double-hyphen (`--`) as an em dash; the em dash (`—`) is used instead. Inline code spans and CLI flags (for example `--squash`) are excluded.
7. **Absence of contradictions.** No document contradicts an existing document that it references.

### Pass Criteria

1. A category passes when every check in the category passes.
2. The suite passes when every category passes.
3. A failing check is reported with the document path and the exact location of the failure.

### Invocation

1. The suite is invoked through the command `Validate Engineering Platform`.
2. The command resolves through the Workflow Registry (`.ai/orchestrator/REGISTRY.md`) to the platform-validation workflow (`.ai/prompts/workflows/platform-validation.md`), the validate-platform task (`.ai/prompts/tasks/validate-platform.md`), and the platform-validation checklist (`.ai/checklists/platform-validation.md`).
3. The suite validates the entire `.ai` directory, not a single document.

### Decision Gates

1. The suite outcome is evaluated against the standard decision gates (`.ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md`).
2. Blocking findings are fixed automatically and the suite is re-run until it passes.
3. A passing suite is a precondition for ratifying a platform change; it does not by itself approve the change.

## Non-Goals

- The suite does not validate the Omnia product code, Swift packages, or their tests.
- The suite does not implement a CI pipeline or automated package verification.
- The suite does not approve or merge changes; it certifies integrity only.

## Related Documents

- `.ai/AI_CONSTITUTION.md` — the governing rules, including the Engineering Command Interface section
- `.ai/README.md` — the framework overview and command reference
- `.ai/orchestrator/REGISTRY.md` — the command-to-workflow dispatch table
- `.ai/specifications/COMMAND_INTERFACE_SPECIFICATION.md` (CMD-000) — the single supported user interaction surface
- `.ai/specifications/WORKFLOW_ORCHESTRATOR_SPECIFICATION.md` (ORCH-000) — the execution model and decision gates
- `.ai/checklists/platform-validation.md` — the executable checklist of the suite
- `.ai/standards/DOCUMENTATION.md` — the documentation standard the suite enforces
