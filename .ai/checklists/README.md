# Checklists

## Purpose

Reusable validation criteria used to evaluate engineering artifacts before they are accepted.

## Contents

- One file per review type: `code-review.md`, `documentation-review.md`.
- Criteria only: checkable items with pass/fail.

## Exclusions

- Review process descriptions (see `prompts/workflows/review.md`).
- Agent role definitions (see `agents/`).

## Relationship

Applied by the Review workflow (`prompts/workflows/review.md`) and by review tasks (`prompts/tasks/`). Pipelines enforce them at validation gates.
