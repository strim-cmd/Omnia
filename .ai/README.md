# AI Development Guide

Welcome to Omnia.

This repository is designed to be developed collaboratively by humans and AI assistants.

This guide is the onboarding document for every AI agent. Read it before doing anything else.

## Read First

Every AI agent MUST read these documents in order before making any change:

1. `.ai/AI_CONSTITUTION.md` — the binding rules for every AI agent
2. `Documentation/Product/PRODUCT_CHARTER.md` — what the product is
3. `Documentation/Product/VISION.md` — why the product exists
4. `.ai/context/` — the current state of the project
5. `.ai/standards/` — the rules for code and documentation
6. `.ai/prompts/` — reusable workflows, task prompts, and document templates
7. `.ai/checklists/` — reusable review checklists

## The .ai Directory

The `.ai` directory is the AI foundation of the repository. It governs how AI agents work on Omnia.

- `.ai/AI_CONSTITUTION.md` — the highest-priority document. Binding rules for every AI agent.
- `.ai/context/` — current project state and working summaries. These are pointers; the source documents win on conflict.
- `.ai/standards/` — engineering standards: Swift, testing, UI, security, git, and documentation.
- `.ai/prompts/` — reusable workflows, task prompts, and document templates.
  - `workflows/` — reusable engineering processes (implementation, review, design, documentation, release).
  - `tasks/` — task-specific prompts that reference workflows, checklists, and templates.
  - `templates/` — reusable document templates (DOCUMENT, PRD, RFC, ADR).
- `.ai/checklists/` — reusable review checklists (code review, documentation review).

## Development Workflow

Issue → Branch → Implementation → Pull Request → Review → Merge

1. Read the constitution and the reading order above.
2. Confirm the task is consistent with the Product Charter and the current architecture.
3. If the task changes architecture or product direction, create an RFC first.
4. Document before implementing.
5. Implement following the standards.
6. Add tests.
7. Open a pull request.
8. Pass review before merge.

## Definition of Done

A task is done when:

- The work follows the architecture.
- Tests pass.
- Documentation is updated.
- No unrelated changes.
- The change has been reviewed.
- Security-sensitive changes received explicit review.

## General Rules

Never invent requirements.

Never contradict existing documentation.

Prefer extending existing architecture over introducing new patterns.

Keep the project simple.

Documentation comes before implementation.

Code must follow Swift 6 best practices.

Native Apple APIs are preferred over third-party libraries.

Security-sensitive changes require explicit review.

When unsure, ask instead of assuming.
