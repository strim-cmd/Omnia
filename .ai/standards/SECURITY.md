---
title: Security Standard
version: 0.1.0
status: Draft
---

# Security Standard

## Purpose

Define the security requirements that protect user data and enforce the product's privacy promises.

## Scope

All code and configuration in the repository.

## Requirements

- Store API keys in Keychain. Never store them in plain text or in user defaults.
- Never send user credentials or conversations to Omnia-owned infrastructure.
- Never proxy or route user AI requests through third parties.
- Enable no telemetry, analytics, or tracking by default.
- Never log secrets, tokens, or conversation content.
- Prefer native, audited Apple security APIs over custom cryptography.
- Review third-party dependencies for security and maintenance health before adding them.

## Sensitive Changes

Security-sensitive changes require explicit review before merging. This includes:

- authentication and credential handling,
- networking and request signing,
- data storage and encryption,
- keychain and entitlement changes.

## Reporting

Security issues must never be reported publicly. Follow the process in `SECURITY.md` at the repository root.

## Related Documents

- `SECURITY.md` (repository root)
- `Documentation/Product/PRODUCT_CHARTER.md`
- `standards/GIT.md`
