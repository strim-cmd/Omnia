---
title: Swift Standard
version: 0.1.0
status: Draft
---

# Swift Standard

## Purpose

Define the Swift coding standard for Omnia so that all code — written by humans and AI assistants — is consistent, safe, and maintainable.

## Scope

All Swift code in `App/`, `Packages/`, `Scripts/`, and `Tools/`.

## Language Mode

- Swift 6 language mode with strict concurrency enabled.
- Build with full warnings enabled.
- Code must follow Swift 6 best practices.

## Concurrency

- Use Swift concurrency: `async`/`await`, actors, and `Sendable`.
- Prefer structured concurrency over manual dispatch.
- Shared mutable state must be isolated. Avoid data races.
- Mark UI-bound code with `@MainActor`.

## API Design

- Follow the Swift API Design Guidelines.
- Prioritize clarity at the point of use.

## Types

- Prefer value types (`struct`) and `enum` for state and models.
- Use `class` or `actor` only where identity or shared state is required.

## Safety

- Avoid force unwrapping and implicitly unwrapped optionals.
- Avoid force casts.
- Use `guard` and `defer` to keep invariants clear.

## Errors

- Throw typed `Error` values.
- Never silently swallow failures.

## Access Control

- Default to `internal`; keep the public surface minimal.
- Use `private` and `fileprivate` where possible.

## Architecture

- Follow the layered architecture: Presentation → Application → Domain → Infrastructure → Foundation.
- The Domain layer must not import SwiftUI or UIKit.
- Prefer native Apple APIs over third-party libraries.

## Security

- Store credentials (for example, API keys) securely on-device using Keychain.
- Never send credentials to Omnia-owned infrastructure.
- Security-sensitive changes require explicit review.

## Tests

- New behavior requires tests.
- Use descriptive test names that state the expected behavior.
- Keep tests fast and deterministic.

## Related Documents

- `context/ARCHITECTURE.md`
- `context/STACK.md`
- `standards/DOCUMENTATION.md`
- `standards/TESTING.md`
