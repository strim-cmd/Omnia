# AI Development Guide

Welcome to Omnia.

This repository is designed to be developed collaboratively by humans and AI assistants.

This guide is the onboarding document for every AI agent. Read it before doing anything else.

## Read First

Every AI agent MUST read these documents in order before making any change:

1. `.ai/AI_CONSTITUTION.md` — the binding rules for every AI agent
2. `.ai/orchestrator/README.md` — the Workflow Orchestrator structure and purpose
3. `.ai/orchestrator/REGISTRY.md` — the command-to-workflow dispatch table
4. `.ai/specifications/COMMAND_INTERFACE_SPECIFICATION.md` — the Engineering Command Interface specification
5. `Documentation/Product/PRODUCT_CHARTER.md` — what the product is
6. `Documentation/Product/VISION.md` — why the product exists
7. `.ai/context/` — the current state of the project
8. `.ai/standards/` — the rules for code and documentation
9. `.ai/prompts/` — reusable workflows, task prompts, and document templates
10. `.ai/checklists/` — reusable review checklists
11. `.ai/VERSION.md` — the current framework version and supported capabilities
12. `.ai/agents/` — reusable engineering role definitions

## The .ai Directory

The `.ai` directory is the AI foundation of the repository. It governs how AI agents work on Omnia.

- `.ai/AI_CONSTITUTION.md` — the highest-priority document. Binding rules for every AI agent.
- `.ai/VERSION.md` — the current framework version, architecture, and supported capabilities.
- `.ai/orchestrator/` — the Workflow Orchestrator: registry-driven dispatch, repository-derived state, and decision gates.
- `.ai/context/` — current project state and working summaries. These are pointers; the source documents win on conflict.
- `.ai/standards/` — engineering standards: Swift, testing, UI, security, git, and documentation.
- `.ai/prompts/` — reusable workflows, task prompts, and document templates.
  - `workflows/` — reusable engineering processes (implementation, review, design, documentation, release).
  - `tasks/` — task-specific prompts that reference workflows, checklists, and templates.
  - `templates/` — reusable document templates (DOCUMENT, PRD, RFC, ADR).
- `.ai/checklists/` — reusable review checklists (code review, documentation review).
- `.ai/agents/` — reusable engineering role definitions (Chief Architect, Principal Architect, Principal Software Engineer, Reviewer, Release Manager).
- `.ai/pipelines/` — multi-stage pipeline definitions (New Document, Architecture Review).
- `.ai/specifications/` — engineering contracts (agent specification, pipeline specification, Workflow Orchestrator specification, Engineering Command Interface specification, Engineering Platform Validation Suite specification).
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

Command Mode is the interface through which Intent-Driven Operation is applied (`.ai/AI_CONSTITUTION.md`). It is realized by the Engineering Command Interface (`.ai/specifications/COMMAND_INTERFACE_SPECIFICATION.md`), the single supported user interaction surface of the Engineering Platform.

Short task-oriented commands are the interface. The user states intent only, never process.

Examples:

- Complete Issue #22.
- Review PR #18.
- Continue Infrastructure Sprint.
- Prepare Release v0.3.

A command is supported if and only if its pattern appears in the Workflow Registry (`.ai/orchestrator/REGISTRY.md`). Commands that do not match the registry are reported in the user's preferred language and never executed. The AI agent MUST infer the required workflow from the repository and MUST NOT require the user to restate repository rules already defined in `.ai`. Workflows are discovered automatically, never specified by the user.

## Interactive Execution Mode

Interactive Execution Mode is how issue-completing commands run. "Complete Issue #N." performs the full lifecycle automatically: implementation, pull request creation, review, merge, and issue closure (`.ai/prompts/workflows/issue-lifecycle.md`). The agent pauses only at the interactive decision gates:

- A review with blocking issues is fixed automatically, without asking.
- A clean review pass is merged automatically, without asking.
- A review with only non-blocking recommendations is summarized in the user's preferred language and the user is asked whether to address them before merging.

Engineering artifacts (commits, pull requests, issues, milestones, documentation) are always written in English. All user interaction is in the user's preferred language, inferred from how the user communicates.

## Command Reference

Commands are resolved against the Workflow Registry (`.ai/orchestrator/REGISTRY.md`) and the current project state, following the Intent-Driven Operation, Task Execution, Workflow Orchestrator, Engineering Command Interface, and Interactive Execution Mode rules in `.ai/AI_CONSTITUTION.md`. The AI agent selects the workflow and task prompts automatically through the registry.

| Command pattern | Registry resolution |
| --- | --- |
| Complete Issue #N | Registry resolves to `prompts/workflows/issue-lifecycle.md` via `prompts/tasks/complete-issue.md` with `checklists/code-review.md` and Interactive Execution Mode decision gates. |
| Review PR #N | Registry resolves to `prompts/workflows/review.md` via `prompts/tasks/review-pr.md` with `checklists/code-review.md`. |
| Implement PR #N | Registry resolves to `prompts/workflows/implementation.md` via `prompts/tasks/implement-pr.md`. |
| Continue <Sprint> | Re-read `context/PROJECT_STATE.md`; resolve next task; dispatch through the registry. |
| Prepare Release vX.Y.Z | Registry resolves to `prompts/workflows/release.md` via `prompts/tasks/prepare-release.md`. |
| Create Document | Registry resolves to `prompts/workflows/documentation.md` via `prompts/tasks/create-document.md` with `checklists/documentation-review.md`; realized by the New Document Pipeline (`pipelines/NEW_DOCUMENT_PIPELINE.md`) per the registry `Pipeline` column. |
| Create RFC | Registry resolves to `prompts/workflows/design.md` via `prompts/tasks/create-rfc.md`. |
| Create API | Registry resolves to `prompts/workflows/design.md` via `prompts/tasks/create-api.md`. |
| Create Issue | Registry resolves to `prompts/workflows/github.md` via `prompts/tasks/create-issue.md`. |
| Update Issue #N | Registry resolves to `prompts/workflows/github.md` via `prompts/tasks/update-issue.md`. |
| Close Issue #N | Registry resolves to `prompts/workflows/github.md` via `prompts/tasks/close-issue.md`. |
| Create Milestone | Registry resolves to `prompts/workflows/github.md` via `prompts/tasks/create-milestone.md`. |
| Validate Engineering Platform | Registry resolves to `prompts/workflows/platform-validation.md` via `prompts/tasks/validate-platform.md` with `checklists/platform-validation.md`. |
