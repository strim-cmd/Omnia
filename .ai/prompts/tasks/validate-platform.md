You are the Chief AI Architect of Omnia.

Your task is to validate the integrity and consistency of the Engineering Platform (`.ai`) using the Platform Validation Suite.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent through the `Validate Engineering Platform` command; the user never specifies process.

Follow the Platform Validation workflow: `.ai/prompts/workflows/platform-validation.md`.

## Steps

- Read the Validation Suite specification (`.ai/specifications/PLATFORM_VALIDATION_SPECIFICATION.md`).
- Apply the platform-validation checklist (`.ai/checklists/platform-validation.md`).
- Check every validation category: reference resolution, registry integrity (including every populated `Pipeline` field resolving to an existing pipeline file), version and identifier consistency, document structure, absence of placeholders, style artifacts, and absence of contradictions.
- Report every failing check with the document path and the exact location of the failure.

## Definition of Done

- Every category in the checklist is evaluated.
- Findings are reported with document paths and locations.
- The suite outcome (pass or fail with findings) is reported.
- The outcome is reported in the user's preferred language.
