# Navigation Stack Modeling Decision (UX audit S3)

## Context

The current navigation model in `NavigationState` and `RootView` represents only the current route (`currentRoute`). The pushed stack is implicit in the SwiftUI `NavigationStack`, and route restoration relies on the container's state.

## Decision

**Keep the current single-route model** for the MVP v0.1 scope. The one-deep stack (conversation list → conversation screen) is sufficient for the current requirements, and the implicit stack in `NavigationStack` is correct for the platform.

## Rationale

1. **Scope**: The MVP v0.1 requires only one level of navigation (list → conversation).
2. **Platform correctness**: SwiftUI `NavigationStack` handles the back-stack semantics correctly for the current use case.
3. **Simplicity**: A single-route model is simpler and sufficient for the current scope.
4. **Future extensibility**: If a second-level navigation need appears (e.g., conversation → settings → provider detail), the model can be revised to a path array through a spec revision (DES-012 §3.5).

## Acceptance Criteria

- [x] Popping always returns to the conversation list
- [x] Scene re-activation restores the current route
- [x] The modeling decision is documented (this file)

## Future Considerations

If the app evolves to require deeper navigation (e.g., conversation → settings → provider detail), the model should be revised to:

1. Represent the navigation path as an array of routes
2. Update `NavigationState` to hold the path
3. Update `RootView` to bind the path to `NavigationStack`
4. Ensure scene re-activation restores the full path

This revision would require a spec update (DES-012 §3.5) and should be driven by a concrete user need.

## References

- UX audit S3 finding
- DES-012 §3.5 (Navigation)
- ARC-006 (Frozen Surfaces)
- PRD-008 (Provider Selection)

## Date

2026-08-08
