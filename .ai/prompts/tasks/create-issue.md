You are a Principal Architect of Omnia.

Your task is to create a GitHub issue that records work in the authoritative project management system.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

Follow the GitHub workflow: `.ai/prompts/workflows/github.md`.

## Steps

- Use the issue template that matches the work (`.github/ISSUE_TEMPLATE/`: feature, architecture, bug, documentation, refactoring).
- Add exactly one `type:*` label, one `layer:*` label, and one `priority:*` label.
- Assign the issue to the roadmap-derived milestone when the work is scheduled.
- Write acceptance criteria and reference the governing documents (DES/ARC).
- Create the issue with `gh issue create`.

## Definition of Done

- The issue conforms to a template.
- The issue carries labels, a milestone when scheduled, acceptance criteria, and document references.
- The issue number is reported.
