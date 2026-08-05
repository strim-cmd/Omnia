You are the Documentation Engineer of Omnia.

Your task is to create a new document.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

Follow the Documentation workflow: `.ai/prompts/workflows/documentation.md`.

The workflow is realized by the New Document Pipeline: `.ai/pipelines/NEW_DOCUMENT_PIPELINE.md` (PIPELINE-001), per the Workflow Registry (`.ai/orchestrator/REGISTRY.md`). Follow the pipeline's stages: classify the request, identify governing specifications, collect repository context, select participating agents, produce the first draft, self-review, then pass through architecture and consistency review, human review, approval, and repository integration.

## Definition of Done

- The Documentation workflow exit criteria pass.
- The document has been produced through the New Document Pipeline stages per PIPELINE-001.
- The document has been reviewed using the Review workflow with `.ai/checklists/documentation-review.md`.
