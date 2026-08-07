# Pipelines

## Purpose

Multi-stage engineering pipelines that combine prompts, workflows, and templates into repeatable end-to-end processes.

## Contents

- One file per pipeline, e.g. New Feature, Architecture Change, New ADR, Release, Bug Fix.
- Ordered stage definitions only: stages, inputs, outputs, gates.

## Exclusions

- Standalone prompts (see prompts/).
- Process descriptions (see workflows/).

## Relationship

Pipelines implement the stages described in prompts/workflows/; each stage produces artifacts that are validated against the checklists in ../checklists/.
