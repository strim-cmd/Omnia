# Review Workflow

Reusable process for reviewing an engineering artifact before it is accepted.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

## Steps

1. Read the artifact and the applicable checklist in `.ai/checklists/`.
2. Evaluate the artifact against every applicable checklist item.
3. Reject solutions that increase unnecessary complexity.
4. Always explain WHY.
5. Suggest concrete improvements.
6. Never rewrite working code without measurable benefit.

## Output

- List every issue found.
- Explain WHY each issue matters.
- Suggest a concrete fix for each issue.
- Return one verdict: Approve, Approve with Recommendations, Needs Revision, or Reject with Rationale.
- Approve only when the applicable checklist passes.
