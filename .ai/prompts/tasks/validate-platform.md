You are the Chief AI Architect of Omnia.

Your task is to validate the integrity and consistency of the Engineering Platform (`.ai`) using the Platform Validation Suite.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent through the `Validate Engineering Platform` command; the user never specifies process.

Follow the Platform Validation workflow: `.ai/prompts/workflows/platform-validation.md`.

## Steps

- Read the Validation Suite specification (`.ai/specifications/PLATFORM_VALIDATION_SPECIFICATION.md`).
- Run the validation script (`bash .ai/scripts/validate-platform.sh`) from the repository root. The script encodes all validation categories: reference resolution, registry integrity (including every populated `Pipeline` field resolving to an existing pipeline file), version and identifier consistency, document structure, absence of placeholders, style artifacts, and absence of contradictions.
- Interpret the script output and report every failing check with the document path and the exact location of the failure.
- If the script cannot run, apply the platform-validation checklist (`.ai/checklists/platform-validation.md`) manually as the authoritative fallback and report that the fallback was used.

## Definition of Done

- Every category in the checklist is evaluated, by the script or by the manual fallback.
- Findings are reported with document paths and locations.
- The suite outcome (pass or fail with findings) is reported.
- The outcome is reported in the user's preferred language.
