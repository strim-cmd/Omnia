# Documentation Workflow

Reusable process for creating a repository document.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

> Realized by the New Document Pipeline (`.ai/pipelines/NEW_DOCUMENT_PIPELINE.md`, PIPELINE-001). The pipeline defines the stage-level coordination of this workflow — classify the request, identify governing specifications, collect context, select participants, draft, self-review, architecture/consistency review, human review, approval, and repository integration — as registered in the Workflow Registry (`../orchestrator/REGISTRY.md`).

## Steps

1. Classify the requested document and identify the governing specifications and the matching template.
2. Read `.ai/standards/DOCUMENTATION.md` and the related source documents so the new document never contradicts them.
3. Reuse the matching template in `.ai/prompts/templates/`:
   - `DOCUMENT.md` for general documents
   - `PRD.md` for product requirements
   - `RFC.md` for proposals
   - `ADR.md` for architecture decisions
4. Follow the requirements:
   - Use Markdown.
   - Write in English.
   - Include the required sections: Purpose, Scope, Requirements, Non-Goals, Related Documents.
   - Add YAML front matter with title, version, status, and metadata.
   - Use Semantic Versioning.
   - Reference source documents explicitly.
   - Do not invent requirements or capabilities.
   - Do not include placeholders, TODO markers, or lorem ipsum.
   - Update related documents that reference the subject.
5. Self-review the draft against `.ai/checklists/documentation-review.md` before external review.

## Exit Criteria

- The document is complete.
- It has a clear purpose.
- It is consistent with the source documents.
- It is ready for review using the Review workflow (`review.md`) with `.ai/checklists/documentation-review.md`.
- The document has been produced through the New Document Pipeline stages per PIPELINE-001.
