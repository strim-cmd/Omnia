# Code Review Checklist

Evaluate the change against every applicable item. A change must pass all applicable items to be approved.

## Product Principles

- [ ] The change is consistent with the Product Charter and Product Principles.
- [ ] No invented requirements.

## Architecture

- [ ] No ADR violation.
- [ ] The layered architecture is respected.
- [ ] Dependencies point downward only; no skip-level or hidden dependencies.
- [ ] The design is consistent with existing architecture documentation.

## Swift Style

- [ ] The code follows `.ai/standards/SWIFT.md`.
- [ ] Swift 6 strict concurrency is respected.
- [ ] Native Apple APIs are preferred over third-party libraries.

## Security

- [ ] No secrets, tokens, API keys, or conversation content are logged, printed, or transmitted.
- [ ] Credentials use the Keychain; never plain text or user defaults.
- [ ] No user data is sent to Omnia-owned infrastructure.
- [ ] Privacy is preserved by default.

## Performance

- [ ] No performance assumptions limit future growth without documented rationale.

## Maintainability

- [ ] The change is understandable without explanation.
- [ ] Tests are added for new behavior and pass.
- [ ] Documentation is updated and related documents stay in sync.
- [ ] No unrelated changes.
- [ ] The change is the smallest solution that satisfies the requirement.
