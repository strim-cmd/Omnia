---
title: Architecture Review Pipeline
document_id: PIPELINE-002
version: 1.1.0
status: Ratified
owner: Chief AI Architect
project: Omnia
created: 2026-08-02
last_updated: 2026-08-02
related_documents:
  - .ai/AI_CONSTITUTION.md
  - .ai/README.md
  - .ai/specifications/PIPELINE_SPECIFICATION.md
  - .ai/agents/AGENT_SPECIFICATION.md
  - .ai/agents/ChiefArchitect.md
  - .ai/pipelines/NEW_DOCUMENT_PIPELINE.md
  - Documentation/Architecture/01_SYSTEM_OVERVIEW.md
  - Documentation/Architecture/ADR/ADR-0001-architectural-style.md
  - Documentation/Architecture/ADR/ADR-0002-dependency-direction.md
supersedes: []
tags:
  - ai
  - pipeline
  - architecture
  - review
---

# Architecture Review Pipeline

> Reference pipeline for the review of all architecture artifacts. This pipeline is the contract example for review pipelines in the repository.

## Executive Summary

Architecture review exists to protect the architectural integrity of Omnia before any architecture artifact is integrated into the repository. Every architecture decision changes the system's long-term shape; an un-reviewed decision becomes costly drift. This pipeline ensures that every architecture artifact is evaluated against the established architecture, the ADRs, and the Product Principles, and that no artifact enters the repository without a recorded review.

## Scope

This pipeline applies to the review of:

- Architecture documents.
- ADRs.
- Module designs.
- System specifications.
- Architecture RFCs.

Exclusions:

- Product documents that do not affect architecture.
- Code implementation and feature implementation.
- Release execution.
- Bug fixes.
- Non-architectural documentation.

## Trigger

This pipeline starts when one of the following occurs:

- A new architecture document.
- An ADR update.
- An architecture refactoring.
- A new subsystem.
- A breaking architectural change.

## Inputs

The following inputs are mandatory:

- **Architecture artifact** — the subject of the review.
- **Relevant ADRs** — the ratified decisions the artifact must respect.
- **SYSTEM_OVERVIEW** — the established system description the artifact must agree with.
- **PRODUCT_CHARTER** — the product direction the artifact must not conflict with.
- **PRODUCT_PRINCIPLES** — the principles the artifact must preserve.
- **AI_CONSTITUTION** — the binding rules for every decision.
- **Repository Standards** — the standards the artifact must follow.

## Participating Agents

Each stage is performed by the role that owns its concern:

- **Chief Architect** — owns the architecture and ADR review.
- **Principal Engineer** — reviews feasibility and implementation impact when applicable.
- **Security Engineer** — reviews security-sensitive architecture when applicable.
- **Documentation Engineer** — verifies documentation completeness.
- **Human Reviewer** — performs the final review and approval.

Responsibility of every participant:

- **Chief Architect** — verifies architecture consistency, dependency direction, layer integrity, and ADR compliance, and returns the architecture verdict.
- **Principal Engineer** — verifies that the artifact can be implemented within the established architecture.
- **Security Engineer** — verifies that security-sensitive architecture meets the security rules.
- **Documentation Engineer** — verifies that the artifact is documented and synchronized with related documents.
- **Human Reviewer** — makes the final judgment that no automated role is authorized to make.

## Review Stages

### Architecture Context Review

- Purpose: evaluate the artifact against the established system description.
- Validation: the artifact is consistent with SYSTEM_OVERVIEW and the architecture documentation.
- Outputs: an architecture context verdict.

### Dependency Review

- Purpose: verify that dependencies point downward only.
- Validation: no skip-level or upward dependency exists.
- Outputs: a dependency verdict.

### Boundary Review

- Purpose: verify that module boundaries remain clear and stable.
- Validation: no hidden coupling and no unclear module ownership.
- Outputs: a boundary verdict.

### Consistency Review

- Purpose: verify the artifact does not contradict the Product Charter or Product Principles.
- Validation: no product conflict and no invented requirements.
- Outputs: a consistency verdict.

### Quality Attribute Review

- Purpose: evaluate the artifact against the quality attributes: privacy, maintainability, and extensibility.
- Validation: no quality attribute is degraded without documented rationale.
- Outputs: a quality attribute verdict.

### Documentation Review

- Purpose: verify the artifact is documented and referenced correctly.
- Validation: documentation is complete and synchronized with related documents.
- Outputs: a documentation verdict.

### Risk Assessment

- Purpose: identify architectural, coupling, and evolution risks.
- Validation: every risk is recorded with a severity and a recommendation.
- Outputs: a risk assessment.

### Final Recommendation

- Purpose: consolidate all verdicts into a single recommendation.
- Validation: the recommendation accounts for every preceding verdict.
- Outputs: a recommendation.

### Human Approval

- Purpose: obtain the final judgment of a human reviewer.
- Validation: the human reviewer understands and accepts the artifact.
- Outputs: an approval decision.

## Validation Gates

The following validation is mandatory at the applicable gates:

- Architecture consistency.
- Dependency direction.
- ADR compliance.
- Layer integrity.
- Provider independence.
- Privacy.
- Maintainability.
- Extensibility.
- Documentation completeness.
- Terminology consistency.

An artifact that fails a gate does not advance.

## Review Outcomes

- **Approved** — every mandatory gate passes; no significant issues remain.
- **Approved with Recommendations** — every mandatory gate passes; optional improvements are recorded and may be addressed later.
- **Needs Revision** — one or more mandatory gates fail; the artifact returns with specific comments.
- **Rejected** — the artifact violates a mandatory rule or an ADR; the rejection includes the rationale.

## Failure Handling

When a review fails, the pipeline:

- stops execution;
- returns the artifact with review comments;
- requests missing information;
- rejects with rationale;
- never silently continues.

## Outputs

The pipeline produces:

- Architecture Review Report.
- Risk Assessment.
- Recommendations.
- Approval Decision.

## Success Criteria

The pipeline is successful when:

- Architecture remains coherent.
- Architectural drift is prevented.
- Repository standards are preserved.
- Documentation remains synchronized.

## Relationship to Other Specifications

This pipeline implements the specifications it references:

- **PIPELINE_SPECIFICATION.md** — the pipeline realizes the contract: ordered stages, gates, agent assignment, and failure handling.
- **AGENT_SPECIFICATION.md** — the pipeline assigns each stage to a role with defined responsibility, authority, and limitations.
- **ChiefArchitect.md** — the pipeline invokes the Chief Architect for architecture and ADR review.
- **ADR-0001** — the pipeline enforces the architectural style and layer integrity.
- **ADR-0002** — the pipeline enforces dependency direction.
- **SYSTEM_OVERVIEW.md** — the pipeline validates artifacts against the system description.

## Version History

- 1.1.0 — Restructured to the full pipeline specification structure.
- 1.0.0 — Initial ratification as the reference architecture review pipeline.
