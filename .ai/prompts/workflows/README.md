# Workflows

## Purpose

Reusable engineering process descriptions. A workflow answers "what happens": the steps, preconditions, and exit criteria of a process.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): workflows are discovered and selected automatically by the agent from user intent; the user never specifies process.

## Contents

- One file per process: `implementation.md`, `review.md`, `design.md`, `documentation.md`, `release.md`, `github.md`, `issue-lifecycle.md`, `platform-validation.md`.
- Process descriptions only: steps and exit criteria.

## Exclusions

- Task-specific prompts (see `../tasks/`).
- Validation criteria (see `../../checklists/`).
- Pipeline stage definitions (see `../../pipelines/`).

## Relationship

Consumed by `../tasks/`; each process is realized by one or more `../../pipelines/` and produces artifacts validated against `../../checklists/`.
