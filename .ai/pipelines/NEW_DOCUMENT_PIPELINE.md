---
title: New Document Pipeline
document_id: PIPELINE-001
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
  - .ai/prompts/templates/
  - .ai/prompts/workflows/
  - .ai/pipelines/README.md
supersedes: []
tags:
  - ai
  - pipeline
  - documentation
  - reference
---

# New Document Pipeline

> Reference implementation of the Pipeline Specification. This pipeline is the contract example for every future pipeline in the repository.

## Executive Summary

This pipeline standardizes the creation of new repository documents. It ensures that every document is produced consistently, follows the repository templates and standards, and passes review before it is accepted. By defining the stages, gates, and participating agents once, this pipeline makes document creation repeatable and predictable across the repository.

## Scope

This pipeline applies to the creation of all documentation types:

- Product documents.
- Architecture documents.
- ADRs.
- Engineering documentation.
- AI Engineering documents.
- Standards.
- Specifications.

Out of scope:

- Code implementation.
- Feature implementation.
- Release execution.
- Bug fixes.
- Any artifact that is not a repository document.

## Trigger

This pipeline starts when one of the following occurs:

- A new document request.
- Missing documentation is identified.
- A new architectural decision.
- A new engineering standard.
- A new product artifact.

## Inputs

The following inputs are mandatory:

- **User request** — required to define the purpose and audience of the document.
- **Relevant repository documents** — required so the new document never contradicts the sources it builds on.
- **AI Constitution** — required because every document is bound by the rules of the constitution.
- **Applicable specifications** — required because the document must conform to the specifications that govern its type.
- **Existing ADRs** — required because the document must respect all ratified architecture decisions.
- **Existing standards** — required because the document must follow the repository standards.

Every input is required because the pipeline validates the document against them. A missing input makes the corresponding validation impossible and blocks the pipeline.

## Participating Agents

Each stage is performed by the role that owns its concern:

- **Documentation Engineer** — produces and self-checks the document.
- **Chief Architect** — reviews architecture, product, ADR, and standard documents.
- **Product Architect** — reviews product documents when applicable.
- **Security Engineer** — reviews security-sensitive documents when applicable.
- **Human Reviewer** — performs the final review and approval.

Responsibility of every participant:

- **Documentation Engineer** — drafts the document from the template and governing specifications, and verifies it against the review checklist.
- **Chief Architect** — verifies architecture consistency, ADR compliance, and dependency on Product Principles.
- **Product Architect** — verifies that product documents agree with the Product Charter.
- **Security Engineer** — verifies that security-sensitive content meets the security rules.
- **Human Reviewer** — makes the final judgment that no automated role is authorized to make.

## Execution Stages

### 1. Classify the Requested Document

- Purpose: determine the document type and the template it must use.
- Inputs: user request.
- Outputs: classified document type.
- Validation criteria: the type maps to a template in `.ai/prompts/templates/`.

### 2. Identify Governing Specifications

- Purpose: determine which specifications and standards bind the document.
- Inputs: classified document type.
- Outputs: the governing specification set.
- Validation criteria: every governing specification is identified and current.

### 3. Collect Repository Context

- Purpose: gather the source documents, ADRs, and standards the new document must not contradict.
- Inputs: applicable repository documents.
- Outputs: a collected context set.
- Validation criteria: the context set covers all sources referenced by the request.

### 4. Select Participating Agents

- Purpose: assign each stage to the responsible role.
- Inputs: document type and governing specifications.
- Outputs: the participating agent set.
- Validation criteria: every stage has a named owner.

### 5. Produce First Draft

- Purpose: create the document from the matching template.
- Inputs: context set, template, governing specifications.
- Outputs: a first draft.
- Validation criteria: the draft follows the template structure and front matter.

### 6. Self-Review

- Purpose: verify the draft against the review checklist before external review.
- Inputs: first draft.
- Outputs: a self-reviewed draft.
- Validation criteria: no placeholders, no invented requirements, references valid.

### 7. Architecture Review

- Purpose: verify architecture consistency and ADR compliance.
- Inputs: self-reviewed draft.
- Outputs: architecture comments and an architecture verdict.
- Validation criteria: no ADR violation, no conflict with the Product Principles.

### 8. Consistency Review

- Purpose: verify the document does not contradict any source document.
- Inputs: reviewed draft and context set.
- Outputs: a consistency verdict.
- Validation criteria: the document agrees with every source it references.

### 9. Human Review

- Purpose: obtain the final judgment of a human reviewer.
- Inputs: consistency-reviewed draft.
- Outputs: a human review verdict.
- Validation criteria: the human reviewer understands and accepts the document.

### 10. Approval

- Purpose: obtain the mandatory approval for the document.
- Inputs: human-reviewed draft.
- Outputs: an approval record.
- Validation criteria: approval is recorded with the approver.

### 11. Repository Integration

- Purpose: place the approved document into the repository at the correct location.
- Inputs: approved document.
- Outputs: a repository-ready artifact.
- Validation criteria: the document is placed under the correct path and is complete.

## Validation Gates

The following validation is mandatory at the applicable gates:

- The document follows the governing specification.
- Terminology is consistent.
- No conflict with the Product Charter.
- No conflict with the Product Principles.
- No conflict with existing ADRs.
- Metadata is complete.
- References are valid.

An artifact that fails a gate does not advance.

## Human Approval

Human approval is mandatory before:

- Merge.
- Introducing new standards.
- Changing architecture.
- Changing product direction.

No automated role may decide these outcomes.

## Failure Handling

When validation fails, the pipeline:

- stops execution;
- returns review comments;
- requests missing information;
- rejects with rationale;
- never silently continues.

## Outputs

The pipeline produces:

- Approved document.
- Review report.
- Improvement recommendations.
- Architecture comments.
- Repository-ready artifact.

## Success Criteria

The pipeline is complete when:

- Documentation is consistent.
- No architectural conflicts.
- Repository standards are followed.
- The output is reusable.
- Minimal human correction is required.

## Relationship to Other Specifications

This pipeline implements the specifications it references:

- **AI_CONSTITUTION.md** — the pipeline enforces the constitution's rules: no invented requirements, documentation first, and respect for the Product Principles.
- **AGENT_SPECIFICATION.md** — the pipeline assigns each stage to a role with defined responsibility, authority, and limitations.
- **PIPELINE_SPECIFICATION.md** — the pipeline realizes the contract: ordered stages, gates, agent assignment, and failure handling.
- **ChiefArchitect.md** — the pipeline invokes the Chief Architect for architecture and ADR review.

## Version History

- 1.1.0 — Restructured to the full pipeline specification structure.
- 1.0.0 — Initial ratification as the reference implementation.

## Related Documents

- `.ai/specifications/PIPELINE_SPECIFICATION.md` — the contract this pipeline implements
- `.ai/agents/AGENT_SPECIFICATION.md` — the agent contract
- `.ai/agents/ChiefArchitect.md` — reference agent implementation (AGENT-001)
- `.ai/prompts/templates/` — reusable document templates
- `.ai/prompts/workflows/` — the workflows this pipeline realizes
