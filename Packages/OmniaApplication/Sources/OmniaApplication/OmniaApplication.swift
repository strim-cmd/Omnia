// OmniaApplication — use cases, application services, and orchestration.

// Re-exports the Domain vocabulary the public services expose, so clients
// (the Presentation layer, DES-012 §4) can name the frozen DES-009 types in
// their own declarations without declaring an OmniaDomain dependency — the
// skip-level edge is never created (ARC-002, ADR-0002, ARC-009). This is a
// re-export of existing symbols; the public contract (DES-011) is unchanged.
@_exported import OmniaDomain
