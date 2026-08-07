---
title: Testing Standard
version: 0.1.0
status: Draft
---

# Testing Standard

## Purpose

Define how Omnia verifies behavior so that regressions are caught early and code can evolve safely.

## Scope

All automated tests: unit, integration, and UI tests.

## Requirements

- New behavior requires tests.
- Fixes should include a regression test when practical.
- Prefer the standard Apple testing frameworks (XCTest and Swift Testing).
- Tests must run in CI before merging.

## Test Structure

- Put tests next to the code they verify, in the same package or target.
- Name tests descriptively: state the behavior under test and the expected result.
- Keep tests independent and deterministic.

## Coverage

- Cover core logic in the Domain layer thoroughly.
- Do not chase 100% coverage; prioritize meaningful assertions.

## Related Documents

- `standards/SWIFT.md`
- `standards/DOCUMENTATION.md`
