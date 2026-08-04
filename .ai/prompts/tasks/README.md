# Tasks

## Purpose

Task-specific prompts that tell an AI agent how to perform a specific job.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): tasks are automatically invoked from user intent; the user never specifies process.

## Contents

- One file per task: `implement-pr.md`, `review-pr.md`, `complete-issue.md`, `create-document.md`, `create-rfc.md`, `create-api.md`, `prepare-release.md`, `create-issue.md`, `update-issue.md`, `close-issue.md`, `create-milestone.md`, `validate-platform.md`.
- Task prompts only: role, task, and definition of done.

## Exclusions

- Reusable process descriptions (see `../workflows/`).
- Validation criteria (see `../../checklists/`).

## Relationship

Each task references a workflow in `../workflows/`, applies a checklist in `../../checklists/`, and produces artifacts using `../templates/`.
