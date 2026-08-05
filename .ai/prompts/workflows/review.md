# Review Workflow

Reusable process for reviewing an engineering artifact before it is accepted.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

> Realized by the Architecture Review Pipeline (`.ai/pipelines/ARCHITECTURE_REVIEW_PIPELINE.md`, PIPELINE-002). The pipeline defines the stage-level coordination of this workflow — architecture context, dependency, boundary, consistency, quality attribute, documentation review, risk assessment, final recommendation, and human approval — as registered in the Workflow Registry (`.ai/orchestrator/REGISTRY.md`). The pipeline's artifact exclusions remain in force: the stage coordination applies when the reviewed artifact falls within the pipeline's scope.

## Steps

1. Read the artifact and the applicable checklist in `.ai/checklists/`.
2. Evaluate the artifact against every applicable checklist item.
3. Reject solutions that increase unnecessary complexity.
4. Always explain WHY.
5. Suggest concrete improvements.
6. Never rewrite working code without measurable benefit.
7. Follow the ARCHITECTURE_REVIEW_PIPELINE review stages for architecture-relevant artifacts: evaluate the artifact against the established system description, verify dependency direction and layer integrity, verify module boundaries, verify consistency with the Product Charter and Product Principles, evaluate the quality attributes, verify documentation completeness, record risks, consolidate the verdicts into a final recommendation, and obtain human approval.

## Output

- List every issue found.
- Explain WHY each issue matters.
- Suggest a concrete fix for each issue.
- Return one verdict: Approve, Approve with Recommendations, Needs Revision, or Reject with Rationale.
- Approve only when the applicable checklist passes.
