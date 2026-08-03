# Workflows

## Purpose

Reusable engineering process descriptions. A workflow answers "what happens": the steps, preconditions, and exit criteria of a process.

## Contents

- One file per process: `implementation.md`, `review.md`, `design.md`, `documentation.md`, `release.md`.
- Process descriptions only: steps and exit criteria.

## Exclusions

- Task-specific prompts (see `../tasks/`).
- Validation criteria (see `../../checklists/`).
- Pipeline stage definitions (see `../../pipelines/`).

## Relationship

Consumed by `../tasks/`; each process is realized by one or more `../../pipelines/` and produces artifacts validated against `../../checklists/`.
