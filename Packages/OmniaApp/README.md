# OmniaApp

The application shell and Composition Root: the Composition Root assembling the complete object graph, the storage layout, the first-run bootstrap, the runtime provider adapter binding, and the macOS executable entry point and lifecycle.

- **Library**: the Composition Root (`CompositionRoot`), the storage layout, the runtime provider adapter binding, the first-run bootstrap, and the app-shell launch sequencing (`AppLaunch`).
- **Executable**: `Omnia` — the SwiftUI `@main` app shell hosting `RootView` (DES-012 §3.5), isolated behind platform availability (DES-013 §3.6).
- **Dependencies**: OmniaPresentation, OmniaApplication, OmniaInfrastructure, OmniaDomain, OmniaFoundation
- **Specifications**: `Documentation/Design/APP_API.md` (DES-013), `Documentation/Architecture/09_PACKAGE_STRUCTURE.md` (ARC-009)
