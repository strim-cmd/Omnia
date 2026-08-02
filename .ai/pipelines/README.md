# Pipelines

## Purpose

Multi-stage engineering pipelines that combine prompts, workflows, and templates into repeatable end-to-end processes.

## Contents

- One file per pipeline, e.g. New Feature, Architecture Change, New ADR, Release, Bug Fix.
- Ordered stage definitions only: stages, inputs, outputs, gates.

## Exclusions

- Standalone prompts (see generation_prompts/ and review_prompts/).
- Process descriptions (see workflows/).

## Relationship

Pipelines implement the stages described in workflows/; each stage produces artifacts that are reviewed using review_prompts/.
