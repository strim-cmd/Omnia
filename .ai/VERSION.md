---
title: AI Engineering Framework
document_id: FRAMEWORK-001
version: 2.5.0
status: Ratified
owner: Chief AI Architect
project: Omnia
created: 2026-08-03
last_updated: 2026-08-04
related_documents:
  - .ai/README.md
  - .ai/AI_CONSTITUTION.md
  - .ai/agents/
  - .ai/prompts/
  - .ai/checklists/
supersedes: []
tags:
  - ai
  - framework
  - governance
  - version
---

# AI Engineering Framework

> Version manifest of the Omnia AI Engineering Framework. Lists the current version, status, architecture, directory layout, and supported capabilities.

## Version

2.5.0

## Status

Ratified

## Architecture

The framework is organized in five layers:

- **Governance** — `AI_CONSTITUTION.md`, `specifications/`, `agents/`. Binding rules, engineering contracts, and reusable role definitions.
- **Operational** — `prompts/workflows/` (reusable processes) and `prompts/tasks/` (task-specific prompts).
- **Production** — `prompts/templates/` (document skeletons).
- **Validation** — `checklists/` (reusable review criteria).
- **Realization** — `pipelines/` (multi-stage pipeline definitions).

`context/` tracks current project state; `standards/` defines the rules for code and documentation; `examples/` holds reference usage.

## Directory Layout

```text
.ai/
├── AI_CONSTITUTION.md
├── README.md
├── VERSION.md
├── agents/
│   ├── README.md
│   ├── AGENT_SPECIFICATION.md
│   ├── ChiefArchitect.md
│   ├── PrincipalArchitect.md
│   ├── PrincipalSoftwareEngineer.md
│   ├── Reviewer.md
│   └── ReleaseManager.md
├── checklists/
│   ├── README.md
│   ├── code-review.md
│   └── documentation-review.md
├── context/
│   ├── ARCHITECTURE.md
│   ├── PRODUCT.md
│   ├── PROJECT.md
│   ├── PROJECT_STATE.md
│   └── STACK.md
├── examples/
│   └── README.md
├── pipelines/
│   ├── README.md
│   ├── ARCHITECTURE_REVIEW_PIPELINE.md
│   └── NEW_DOCUMENT_PIPELINE.md
├── prompts/
│   ├── README.md
│   ├── workflows/
│   │   ├── README.md
│   │   ├── implementation.md
│   │   ├── review.md
│   │   ├── design.md
│   │   ├── documentation.md
│   │   ├── release.md
│   │   ├── github.md
│   │   └── issue-lifecycle.md
│   ├── tasks/
│   │   ├── README.md
│   │   ├── implement-pr.md
│   │   ├── review-pr.md
│   │   ├── complete-issue.md
│   │   ├── create-document.md
│   │   ├── create-rfc.md
│   │   ├── create-api.md
│   │   ├── prepare-release.md
│   │   ├── create-issue.md
│   │   ├── update-issue.md
│   │   ├── close-issue.md
│   │   └── create-milestone.md
│   └── templates/
│       ├── README.md
│       ├── DOCUMENT.md
│       ├── PRD.md
│       ├── RFC.md
│       └── ADR.md
├── specifications/
│   └── PIPELINE_SPECIFICATION.md
└── standards/
    ├── DOCUMENTATION.md
    ├── GIT.md
    ├── SECURITY.md
    ├── SWIFT.md
    ├── TESTING.md
    └── UI.md
```

## Supported Workflows

| Workflow | File |
| --- | --- |
| Implementation | `prompts/workflows/implementation.md` |
| Review | `prompts/workflows/review.md` |
| Design | `prompts/workflows/design.md` |
| Documentation | `prompts/workflows/documentation.md` |
| Release | `prompts/workflows/release.md` |
| GitHub | `prompts/workflows/github.md` |
| Interactive Execution (issue lifecycle) | `prompts/workflows/issue-lifecycle.md` |

## Supported Tasks

| Task | File |
| --- | --- |
| Implement PR | `prompts/tasks/implement-pr.md` |
| Review PR | `prompts/tasks/review-pr.md` |
| Complete Issue | `prompts/tasks/complete-issue.md` |
| Create Document | `prompts/tasks/create-document.md` |
| Create RFC | `prompts/tasks/create-rfc.md` |
| Create API | `prompts/tasks/create-api.md` |
| Prepare Release | `prompts/tasks/prepare-release.md` |
| Create Issue | `prompts/tasks/create-issue.md` |
| Update Issue | `prompts/tasks/update-issue.md` |
| Close Issue | `prompts/tasks/close-issue.md` |
| Create Milestone | `prompts/tasks/create-milestone.md` |

## Supported Checklists

| Checklist | File |
| --- | --- |
| Code Review | `checklists/code-review.md` |
| Documentation Review | `checklists/documentation-review.md` |

## Version History

- 2.5.0 — Added Interactive Execution Mode: "Complete Issue #N" runs the full issue lifecycle automatically — implementation, pull request creation, review, merge, and issue closure — through the Interactive Execution workflow (`prompts/workflows/issue-lifecycle.md`) and the complete-issue task (`prompts/tasks/complete-issue.md`). Interactive decision gates: blocking review issues are fixed automatically, clean reviews are merged automatically, and non-blocking recommendations are summarized and confirmed in the user's preferred language. Engineering artifacts are always in English; user interaction is in the user's preferred language.
- 2.4.0 — Finalized command mode through a single Intent-Driven Operation principle in the AI Constitution: user prompts express intent only, workflows are discovered automatically, GitHub Issues/PRs/Milestones and PROJECT_STATE are the authoritative project state, and `.ai` is the single source of engineering process truth.
- 2.3.0 — Added command mode: task execution rules in the AI Constitution, a command reference in the README, and short task-oriented commands as the preferred interface.
- 2.2.0 — Added GitHub project management: the GitHub workflow (`prompts/workflows/github.md`) and GitHub tasks (create-issue, update-issue, close-issue, create-milestone). GitHub is the authoritative project management system, managed through the GitHub CLI.
- 2.1.0 — Finalized framework: introduced reusable engineering roles (Principal Architect, Principal Software Engineer, Reviewer, Release Manager); added this version manifest.
- 2.0.0 — Reorganized prompts into reusable workflows, tasks, and templates; introduced checklists.
- 1.0.0 — Initial AI Foundation: constitution, standards, prompts, templates, pipelines, agents, specifications.
