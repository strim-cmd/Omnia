# Platform Validation Workflow

Reusable process for validating the integrity and consistency of the Engineering Platform (`.ai`).

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent through the `Validate Engineering Platform` command; the user never specifies process.

## Preconditions

1. The command has been resolved against the Workflow Registry (`.ai/orchestrator/REGISTRY.md`).
2. The platform-validation checklist exists (`.ai/checklists/platform-validation.md`).
3. The Validation Suite specification is available (`.ai/specifications/PLATFORM_VALIDATION_SPECIFICATION.md`).

## Steps

1. **Load the contract.** Read the Validation Suite specification (`.ai/specifications/PLATFORM_VALIDATION_SPECIFICATION.md`) to determine the validation categories and pass criteria.
2. **Inventory the platform.** Enumerate the `.ai` directory: specifications, standards, orchestrator, checklists, workflows, tasks, templates, and context documents.
3. **Check reference resolution.** Verify every file reference in `.ai` documents (inline paths and front matter `related_documents`) resolves to an existing file.
4. **Check registry integrity.** Verify every command pattern in `.ai/orchestrator/REGISTRY.md` resolves to existing workflow, task, and checklist files.
5. **Check version and identifier consistency.** Verify `document_id` uniqueness and version agreement between documents.
6. **Check document structure.** Verify front matter and required sections per the Documentation standard (`.ai/standards/DOCUMENTATION.md`).
7. **Check for placeholders.** Verify no TODO markers, lorem ipsum, or template placeholder text.
8. **Check style artifacts.** Verify no prose uses double-hyphen (`--`) as an em dash; exclude inline code spans and CLI flags.
9. **Check for contradictions.** Verify no document contradicts a document it references.
10. **Report findings.** Report every failing check with the document path and exact location.

## Exit Criteria

- Every category in the checklist is evaluated.
- Findings are reported with document paths and locations.
- The suite outcome (pass or fail with findings) is reported.
- A passing suite certifies platform integrity; it does not by itself approve a change.
