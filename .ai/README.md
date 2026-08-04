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
8. `.ai/VERSION.md` — the current framework version and supported capabilities
9. `.ai/agents/` — reusable engineering role definitions

## The .ai Directory

The `.ai` directory is the AI foundation of the repository. It governs how AI agents work on Omnia.

- `.ai/AI_CONSTITUTION.md` — the highest-priority document. Binding rules for every AI agent.
- `.ai/VERSION.md` — the current framework version, architecture, and supported capabilities.
- `.ai/context/` — current project state and working summaries. These are pointers; the source documents win on conflict.
- `.ai/standards/` — engineering standards: Swift, testing, UI, security, git, and documentation.
- `.ai/prompts/` — reusable workflows, task prompts, and document templates.
  - `workflows/` — reusable engineering processes (implementation, review, design, documentation, release).
  - `tasks/` — task-specific prompts that reference workflows, checklists, and templates.
  - `templates/` — reusable document templates (DOCUMENT, PRD, RFC, ADR).
- `.ai/checklists/` — reusable review checklists (code review, documentation review).
- `.ai/agents/` — reusable engineering role definitions (Chief Architect, Principal Architect, Principal Software Engineer, Reviewer, Release Manager).
- `.ai/pipelines/` — multi-stage pipeline definitions (New Document, Architecture Review).
- `.ai/specifications/` — engineering contracts (agent and pipeline specifications).
- `.ai/examples/` — reference examples of framework usage.

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

GitHub is the authoritative project management system for Omnia. Issues, milestones, labels, and the Omnia Roadmap project are managed through the GitHub workflow (`.ai/prompts/workflows/github.md`) using the GitHub CLI (`gh`).

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

## Command Mode

Command Mode is the interface through which Intent-Driven Operation is applied (`.ai/AI_CONSTITUTION.md`).

Short task-oriented commands are the preferred interface. The user states intent only, never process.

Examples:

- Complete Issue #22.
- Review PR #18.
- Continue Infrastructure Sprint.
- Prepare Release v0.3.

The AI agent MUST infer the required workflow from the repository and MUST NOT require the user to restate repository rules already defined in `.ai`. Workflows are discovered automatically, never specified by the user.

## Command Reference

Commands are resolved against the GitHub artifact and the current project state, following the Intent-Driven Operation and Task Execution rules in `.ai/AI_CONSTITUTION.md`. The AI agent selects the workflow and task prompts automatically.

| Command pattern | Resolution |
| --- | --- |
| Complete Issue #N | Treat the GitHub Issue as authoritative, then follow `prompts/tasks/implement-pr.md` via `prompts/workflows/implementation.md`. |
| Review PR #N | Follow `prompts/tasks/review-pr.md` via `prompts/workflows/review.md` with `checklists/code-review.md`. |
| Continue <Sprint> | Determine the next task from `context/PROJECT_STATE.md` and the matching roadmap, then follow the relevant workflow. |
| Prepare Release vX.Y.Z | Follow `prompts/tasks/prepare-release.md` via `prompts/workflows/release.md`. |
| Create <Document/RFC/API/Issue/Milestone> | Follow the corresponding `prompts/tasks/` prompt. |
