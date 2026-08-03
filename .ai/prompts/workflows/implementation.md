# Implementation Workflow

Reusable process for implementing a feature or change in Omnia.

## Preconditions

1. Confirm the change is consistent with the Product Charter and the current architecture.
2. If the change alters architecture or product direction, run the Design workflow (`design.md`) and create an RFC before implementing.
3. Read the context documents in order:
   - `.ai/context/PROJECT.md`
   - `.ai/context/PRODUCT.md`
   - `.ai/context/ARCHITECTURE.md`
   - `.ai/context/STACK.md`
4. Read the standards:
   - `.ai/standards/SWIFT.md`
   - `.ai/standards/TESTING.md`
   - `.ai/standards/UI.md`
   - `.ai/standards/SECURITY.md`
   - `.ai/standards/GIT.md`

## Steps

1. Document before implementing: update the relevant documentation as part of the change.
2. Follow the layered architecture: Presentation → Application → Domain → Infrastructure → Foundation.
3. Dependencies point downward only. The Domain layer must not import SwiftUI or UIKit.
4. Use Swift 6 with strict concurrency.
5. Prefer native Apple APIs over third-party libraries.
6. Add tests for new behavior following `.ai/standards/TESTING.md`.

## Exit Criteria

- The change works on the supported platforms.
- Tests pass.
- Documentation is updated.
- No unrelated changes.
- The change is ready for review using the Review workflow (`review.md`).
