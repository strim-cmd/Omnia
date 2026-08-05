# Templates

## Purpose

Reusable document skeletons that define the required structure and front matter of engineering artifacts.

## Contents

- One file per artifact type: `DOCUMENT.md`, `PRD.md`, `RFC.md`, `ADR.md`.
- Empty skeletons only, with defined sections and metadata fields.

## Exclusions

- Completed or filled-in documents (see `../../examples/`).
- Workflow and task prompts.

## Relationship

Filled in by `../tasks/` following `../workflows/`; the resulting artifacts are validated against the checklists in `../../checklists/`.
