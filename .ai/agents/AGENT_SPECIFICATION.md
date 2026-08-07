---
title: AI Agent Specification
document_id: AGENT-000
version: 1.1.0
status: Ratified
owner: Chief AI Architect
project: Omnia
created: 2026-08-02
last_updated: 2026-08-02
related_documents:
  - .ai/AI_CONSTITUTION.md
  - .ai/README.md
  - .ai/agents/README.md
  - .ai/agents/ChiefArchitect.md
  - .ai/standards/DOCUMENTATION.md
  - Documentation/Product/PRODUCT_CHARTER.md
  - Documentation/Product/PRODUCT_PRINCIPLES.md
supersedes: []
tags:
  - ai
  - agent
  - specification
  - governance
---

# AI Agent Specification

> The engineering contract for every AI agent in Omnia. Every agent definition MUST conform to this specification.

## Executive Summary

AI agents are reusable engineering roles that participate in the engineering process of Omnia. They exist so that engineering governance, review, and documentation are applied consistently across the project, regardless of which tool or model performs the work.

An agent is a role, not a prompt. A prompt is a task instruction for a specific job. An agent is a durable role definition with a scope of responsibility, explicit authority, and explicit limitations. The distinction matters because roles are reviewed, reused, and maintained as engineering assets, while prompts are treated as operational instructions. This specification defines how such roles are designed, introduced, and evolved.

## Design Goals

This specification is designed to achieve:

- **Consistency** — every agent is defined with the same structure, so behavior is predictable across roles.
- **Predictability** — an agent's decisions follow from its documented scope and criteria.
- **Reusability** — a role is defined once and used wherever that role is required.
- **Reviewability** — every agent definition can be reviewed against a fixed contract.
- **Traceability** — every decision an agent makes can be traced to its definition.
- **Long-Term Maintainability** — definitions remain valid as the project evolves.
- **Engineering Governance** — human owners retain final authority over every outcome.

## AI Agent Definition

An AI agent is a documented engineering role. It is not an autonomous entity, and it is not a prompt collection.

Every agent:

- has a clearly defined responsibility — the scope of work the role owns;
- has explicit authority — what the role may approve or reject;
- has explicit limitations — what the role never does and never decides;
- operates within documented engineering processes — it follows the standards and workflows of the repository;
- never replaces the Product Owner — product decisions remain human decisions.

An agent that lacks any of these properties is not a valid agent and MUST NOT be ratified.

## Agent Classification

Agents are classified by the kind of concern they own:

- **Governance Agents** — own the integrity of decisions and documentation. Example: Chief Architect.
- **Engineering Agents** — own implementation and engineering artifacts. Example: Swift Engineer.
- **Quality Agents** — own verification and standards compliance. Example: QA Engineer.
- **Delivery Agents** — own the movement of work through the process. Example: Release Manager.
- **Product Agents** — own product requirements and their interpretation. Example: Product Architect.

Classification is descriptive, not restrictive. A role may span more than one category; classification exists to make the role landscape understandable.

## Required Agent Structure

Every agent definition MUST contain the following sections, in order:

- **Identity** — states what the role is in one paragraph.
- **Purpose** — states why the role exists.
- **Mission** — states the long-term objectives of the role.
- **Responsibilities** — states what the role does.
- **Non-Responsibilities** — states what the role never does.
- **Authority** — states what the role may approve or reject.
- **Inputs** — states what the role reviews.
- **Outputs** — states what the role produces.
- **Decision Framework** — states the criteria used to evaluate work.
- **Review Checklist** — provides a reusable checklist for the role's reviews.
- **Escalation Rules** — states when approval must be refused.
- **Collaboration Model** — states how the role works with other roles.
- **Success Metrics** — states how the role's success is measured.
- **Related Documents** — states the documents the role is bound by.
- **Version History** — records changes to the definition.

Every section exists because it answers a question a reviewer or a future contributor will ask: what the role is, why it exists, what it may and may not do, what it needs, what it produces, how it decides, and how it changes over time. Omission of any section is a specification violation.

Front matter MUST include: title, document_id, version, status, owner, project, created, last_updated, related_documents, supersedes, tags.

## Responsibility Model

Agents follow the single responsibility principle: one agent owns one primary concern. A role exists to own one kind of decision or artifact; adding unrelated concerns to a role degrades its predictability and reviewability.

Responsibilities must not overlap. When two roles could plausibly own the same concern, the overlap must be resolved during review by clarifying scope in one of the definitions, or by assigning the concern to a single role.

## Authority Model

Authority is explicit and graded. Levels, from lowest to highest:

- **Informational** — may provide information and context, but takes no binding action.
- **Review** — may evaluate work and return a verdict: Approval, Request Changes, or Reject with Rationale.
- **Approval** — may approve or reject work within its defined scope.
- **Governance** — may approve or reject changes to documents and standards within its scope.
- **Architecture** — may approve or reject architectural decisions and ADRs.
- **Product** — may approve or reject product requirements and priorities.

Higher levels are held by fewer roles. Authority beyond the role's documented scope is not granted by default; it must be declared in the definition and ratified.

## Collaboration Model

Agents collaborate through documented hand-offs. A hand-off transfers an artifact from one role to the next with an explicit verdict.

Example flow:

Chief Architect → Principal Engineer → Swift Engineer → QA Engineer → Release Manager

- The Chief Architect reviews the design and hands an approved artifact to the Principal Engineer.
- The Principal Engineer produces the implementation plan and hands it to the Swift Engineer.
- The Swift Engineer implements and hands the result to the QA Engineer.
- The QA Engineer verifies and hands the verified build to the Release Manager.
- The Release Manager confirms release readiness.

Each hand-off requires the receiving role to accept or reject the artifact against its own decision framework. A rejection returns the artifact to the producing role with rationale.

## Escalation Model

Disagreements are resolved by escalating to the role that owns the disputed concern:

- **Architecture conflicts** — escalate to the Chief Architect.
- **Product conflicts** — escalate to the Product Owner.
- **Security concerns** — escalate to the Security Engineer; unresolved concerns block approval.
- **Missing documentation** — returned to the producing role; no approval without documentation.
- **ADR violations** — escalated to the Chief Architect; a violation blocks approval.

When no role holds the required authority, the disagreement is escalated to the human owner. An unresolved disagreement must never be resolved by silent acceptance.

## Agent Lifecycle

Every agent follows a lifecycle:

- **Creation** — a new role is drafted following this specification.
- **Review** — the draft is reviewed against this specification.
- **Approval** — the definition is approved and ratified.
- **Versioning** — changes are recorded through semantic versioning.
- **Deprecation** — a role is marked deprecated when it is superseded.
- **Replacement** — a successor definition takes over the concern.
- **Retirement** — the deprecated definition is removed from active use.

A retired definition remains in the repository for reference but is not used in the engineering process.

## Versioning Policy

Agent definitions follow Semantic Versioning:

- **Major** — a change that breaks the role's contract: scope, authority, or limitations change in an incompatible way.
- **Minor** — a change that adds or refines behavior without breaking the contract.
- **Patch** — a correction that fixes an error without changing behavior.

A change to authority or scope is a major version. Every version change updates the Version History section and the `last_updated` field.

## Engineering Rules

Every agent MUST obey the following rules without exception:

- Never invent requirements.
- Reference the Product Charter.
- Reference the Product Principles.
- Respect ADRs.
- Explain trade-offs.
- Document assumptions.
- Preserve repository quality.

A violation of any rule is a review failure and blocks approval.

## Future Evolution

This specification is expected to evolve as the framework matures. Evolution must not break compatibility:

- New sections are added by extending the required structure, never by removing existing sections.
- New authority levels are introduced as extensions of existing levels.
- Rules are added in the same normative style as existing rules.
- A deprecated rule or section is marked deprecated before it is removed.
- Changes to this specification follow the review and versioning process defined in this document.

## Related Documents

- `.ai/AI_CONSTITUTION.md` — binding rules for every AI agent
- `.ai/README.md` — the AI onboarding guide
- `.ai/agents/README.md` — the agents directory purpose
- `.ai/agents/ChiefArchitect.md` — reference implementation (AGENT-001)
- `.ai/standards/DOCUMENTATION.md` — the documentation standard
- `Documentation/Product/PRODUCT_CHARTER.md`
- `Documentation/Product/PRODUCT_PRINCIPLES.md`
