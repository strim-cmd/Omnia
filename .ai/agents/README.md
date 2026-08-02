# Agents

## Purpose

Reusable AI role definitions used across the engineering process. Each agent is a named role with a defined scope of responsibility and authority.

## Contents

- One file per agent role, e.g. Chief Architect, Swift Engineer, Product Architect, Security Engineer, QA Engineer.
- Role definitions only: scope, responsibilities, constraints, authority.

## Exclusions

- Prompts of any kind (see generation_prompts/ and review_prompts/).
- Workflow and pipeline definitions.

## Relationship

Agents drive generation_prompts/ and review_prompts/, execute pipelines/, and are bound by the standards in ../standards/ and ../AI_CONSTITUTION.md.
