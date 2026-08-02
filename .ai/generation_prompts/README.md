# Generation Prompts

## Purpose

Reusable prompt specifications for generating new engineering artifacts from templates.

## Contents

- One file per artifact type, e.g. ADR, Architecture Document, Swift Module, RFC, API Specification.
- Prompt specifications only: inputs, rules, output requirements.

## Exclusions

- Review criteria (see review_prompts/).
- Agent role definitions (see agents/).

## Relationship

Consumed by agents/ during artifact creation; outputs conform to templates/ and are verified against review_prompts/.
