# Prompts

## Purpose

Operational instructions for engineering tasks. The prompts framework separates reusable workflows from task-specific prompts, backed by reusable templates and checklists.

## Structure

- `workflows/` — reusable engineering processes (implementation, review, design, documentation, release). Referenced by tasks.
- `tasks/` — task-specific prompts that reference a workflow, a checklist, and a template.
- `templates/` — reusable document skeletons (DOCUMENT, PRD, RFC, ADR).

## Relationship

Tasks run workflows; workflows produce artifacts from `templates/`; artifacts are validated against the checklists in `../checklists/` during the Review workflow. Agents (`../agents/`) and pipelines (`../pipelines/`) realize this framework and are bound by `../standards/` and `../AI_CONSTITUTION.md`.
