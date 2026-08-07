# Platform Validation Workflow

Reusable process for validating the integrity and consistency of the Engineering Platform (`.ai`).

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent through the `Validate Engineering Platform` command; the user never specifies process.

## Preconditions

1. The command has been resolved against the Workflow Registry (`.ai/orchestrator/REGISTRY.md`).
2. The platform-validation checklist exists (`.ai/checklists/platform-validation.md`).
3. The Validation Suite specification is available (`.ai/specifications/PLATFORM_VALIDATION_SPECIFICATION.md`).
4. The validation script exists (`.ai/scripts/validate-platform.sh`).

## Steps

1. **Load the contract.** Read the Validation Suite specification (`.ai/specifications/PLATFORM_VALIDATION_SPECIFICATION.md`) to determine the validation categories and pass criteria.
2. **Inventory the platform.** Enumerate the `.ai` directory: specifications, standards, orchestrator, checklists, workflows, tasks, templates, and context documents.
3. **Run the validation script.** Execute `bash .ai/scripts/validate-platform.sh` from the repository root. The script encodes the validation categories deterministically (reference resolution, registry integrity, version and identifier consistency, document structure, absence of placeholders, style artifacts, and absence of contradictions) and exits non-zero on any failing check.
4. **Interpret the output.** For every failing check reported by the script, locate the exact document path and location. If the script cannot run (for example, the environment lacks the script's dependencies), apply the platform-validation checklist (`.ai/checklists/platform-validation.md`) manually as the authoritative fallback and report that the fallback was used.
5. **Reconcile with the checklist.** The manual checklist remains the authoritative specification and fallback; the script results and the checklist results must agree. If they disagree, investigate before reporting the outcome.
6. **Report findings.** Report every failing check with the document path and exact location.

## Exit Criteria

- Every category in the checklist is evaluated, by the script or by the manual fallback.
- Findings are reported with document paths and locations.
- The suite outcome (pass or fail with findings) is reported.
- A passing suite certifies platform integrity; it does not by itself approve a change.
