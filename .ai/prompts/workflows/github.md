# GitHub Workflow

Reusable process for AI agents to use GitHub as the authoritative project management system for Omnia, through the GitHub CLI (`gh`).

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

## Purpose

GitHub records the project's plan and progress: issues, milestones, labels, and the Omnia Roadmap project. This workflow defines how agents create, update, and close that state so the result stays consistent with the AI Engineering Framework.

## Preconditions

1. `gh` is installed and authenticated (`gh auth status`).
2. The repository and its default branch are known.
3. The label taxonomy (`type:*`, `layer:*`, `priority:*`), the roadmap-derived milestones, and the Omnia Roadmap project exist.
4. The agent has read the context documents and standards listed in `.ai/README.md`.

## Steps

1. **Inspect before changing.** Read the current GitHub state before any operation: labels, milestones, open issues, and project items. Never recreate existing resources.
2. **Use labels deliberately.** Apply exactly one `type:*`, one `layer:*` (when the change touches a layer), and one `priority:*` label. Never create duplicate or ad-hoc labels.
3. **Use milestones derived from the roadmap.** Create a milestone only from an approved roadmap. Completed milestones are closed; active and planned milestones are open.
4. **Create issues from templates.** An issue enters through the matching issue template (`.github/ISSUE_TEMPLATE/`: feature, architecture, bug, documentation, refactoring). Every issue carries labels, a milestone when scheduled, acceptance criteria, and references to the governing DES/ARC documents.
5. **Update issues explicitly.** Use `gh issue edit` to change title, body, labels, milestone, or assignees. Preserve the acceptance criteria.
6. **Close issues only when the work is done.** Close an issue only when its acceptance criteria are met. A pull request closes its issue through `Closes #N` in the PR body.
7. **Track work on the project.** Move items through the Omnia Roadmap Status: Backlog, Ready, In Progress, Review, Done.

## Exit Criteria

- Every issue created conforms to a template and carries the correct labels and milestone.
- Every reference to a document, label, milestone, or project resolves.
- No resource is duplicated.
- The GitHub state change is reported with its identifiers (issue numbers, milestone numbers, project item ids).
