# Platform Validation Checklist

Evaluate the Engineering Platform (`.ai`) against the checks below. Approve only when every applicable item passes.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent through the `Validate Engineering Platform` command; the user never specifies process.

## Reference Resolution

- [ ] Every file reference in `.ai` documents (inline paths and front matter `related_documents`) resolves to an existing file.
- [ ] No reference points outside the repository without a valid external target.

## Registry Integrity

- [ ] Every command pattern in `.ai/orchestrator/REGISTRY.md` resolves: its workflow, task, and checklist files exist.
- [ ] The registry contains no entry pointing to a non-existent workflow, task, or checklist.

## Version and Identifier Consistency

- [ ] Every document with a `document_id` uses a unique identifier.
- [ ] Version references between documents agree with the referenced documents' own front matter.
- [ ] The framework version (`VERSION.md`) is consistent with the version history entries.

## Document Structure

- [ ] Every formal document in `specifications/`, `orchestrator/`, and `standards/` carries YAML front matter with title, version, and status.
- [ ] Formal documents follow `.ai/standards/DOCUMENTATION.md`; structure requirements apply when applicable.

## Absence of Placeholders

- [ ] No document contains unresolved template markers, lorem ipsum, or placeholder text intended to be replaced before commit.
- [ ] Checklist and review documents that name these markers to define the check are not affected.

## Style Artifacts

- [ ] No prose uses double-hyphen (`--`) as an em dash.
- [ ] Inline code spans and CLI flags (for example `--squash`) are excluded.

## Absence of Contradictions

- [ ] No document contradicts a document it references.
- [ ] No document invents requirements absent from its source documents.
