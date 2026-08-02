# Review Prompts

## Purpose

Reusable review specifications for evaluating engineering artifacts before they are accepted.

## Contents

- One file per review type, e.g. Architecture Review, Security Review, Swift Review, Documentation Review, Product Review.
- Review specifications only: scope, criteria, severity rules.

## Exclusions

- Generation prompts (see generation_prompts/).
- Agent role definitions (see agents/).

## Relationship

Complementary to generation_prompts/. Applied during pipelines/ to check that artifacts produced from templates/ meet the criteria defined here.
