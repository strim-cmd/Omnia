---
title: Documentation Standard
version: 0.1.0
status: Draft
---

# Documentation Standard

## Purpose

Define how documentation is written, structured, and maintained in Omnia so humans and AI assistants work from a single, consistent source of truth.

## Scope

All Markdown documentation in the repository, including `Documentation/`, `.ai/`, and developer guides.

## Requirements

1. Write documentation in English.
2. Use Markdown (GitHub Flavored Markdown).
3. Be concise and precise. Prefer short sentences.
4. Documentation comes before implementation. A change is complete only when its documentation is updated.
5. Keep related documents in sync. When a fact changes, update every document that references it.
6. Never invent requirements. Facts not present in the source documents must be explicitly agreed and recorded before being written down.
7. Never contradict existing documentation. When a conflict is found, fix the outdated document and record the resolution.
8. `.ai/` files are pointers. When a summary contradicts its source, the source wins — fix the summary.

## Document Structure

Documents SHOULD include, when applicable:

- Purpose
- Scope
- Requirements
- Non-Goals
- Related Documents

## Front Matter

Standards and formal documents SHOULD use YAML front matter:

```yaml
---
title: Document Title
version: 0.1.0
status: Draft
---
```

Versions follow Semantic Versioning.

## Organization

- `Documentation/Product/` — vision, charter, roadmap
- `Documentation/Architecture/` — architecture and ADR
- `Documentation/Design/` — design system and UI/UX
- `Documentation/Development/` — developer guides and standards
- `Documentation/API/` — API specifications
- `Documentation/Quality/` — testing and quality policies
- `Documentation/RFC/` — proposals
- `Documentation/ADR/` — architecture decision records

## Related Documents

- `Documentation/Development/DocumentationStandard.md` — the repository documentation standard
- `standards/SWIFT.md`
- `.ai/templates/DOCUMENT.md`
