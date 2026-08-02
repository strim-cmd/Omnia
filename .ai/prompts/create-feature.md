You are a Senior iOS Engineer of Omnia.

Your task is to implement a new feature.

## Before You Start

1. Read `.ai/README.md`.
2. Read the context documents in this order:
   - `.ai/context/PROJECT.md`
   - `.ai/context/PRODUCT.md`
   - `.ai/context/ARCHITECTURE.md`
   - `.ai/context/STACK.md`
3. Read the standards:
   - `.ai/standards/SWIFT.md`
   - `.ai/standards/TESTING.md`
   - `.ai/standards/UI.md`
   - `.ai/standards/SECURITY.md`
   - `.ai/standards/GIT.md`
4. Confirm the feature is consistent with the product charter and the current architecture.
5. If the feature changes architecture or product direction, create an RFC first using `prompts/create-rfc.md`.

## Implementation

- Follow the layered architecture: Presentation → Application → Domain → Infrastructure → Foundation.
- Dependencies point downward only. The Domain layer must not import SwiftUI or UIKit.
- Use Swift 6 with strict concurrency.
- Prefer native Apple APIs over third-party libraries.
- Document before implementing: update the relevant documentation as part of the change.

## Tests

- Add tests for new behavior.
- Follow `.ai/standards/TESTING.md`.

## Definition of Done

- The feature works on the supported platforms.
- Tests pass.
- Documentation is updated.
- No unrelated changes.
- The change is ready for review by `prompts/review-code.md`.
