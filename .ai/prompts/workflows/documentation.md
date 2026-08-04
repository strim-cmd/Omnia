# Documentation Workflow

Reusable process for creating a repository document.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

## Steps

1. Read `.ai/standards/DOCUMENTATION.md` and the related source documents so the new document never contradicts them.
2. Reuse the matching template in `.ai/prompts/templates/`:
   - `DOCUMENT.md` for general documents
   - `PRD.md` for product requirements
   - `RFC.md` for proposals
   - `ADR.md` for architecture decisions
3. Follow the requirements:
   - Use Markdown.
   - Write in English.
   - Include the required sections: Purpose, Scope, Requirements, Non-Goals, Related Documents.
   - Add YAML front matter with title, version, status, and metadata.
   - Use Semantic Versioning.
   - Reference source documents explicitly.
   - Do not invent requirements or capabilities.
   - Do not include placeholders, TODO markers, or lorem ipsum.
   - Update related documents that reference the subject.

## Exit Criteria

- The document is complete.
- It has a clear purpose.
- It is consistent with the source documents.
- It is ready for review using the Review workflow (`review.md`) with `.ai/checklists/documentation-review.md`.
